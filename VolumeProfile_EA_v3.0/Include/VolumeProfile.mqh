//+------------------------------------------------------------------+
//|                       VolumeProfile.mqh                          |
//|                   Volume Profile Calculation Module               |
//|                          Phase 2 Refactor                         |
//|                                                                  |
//| Description:                                                     |
//|   Modular extraction of all volume profile calculation logic     |
//|   from Phase 1 monolithic EA. Handles 400-bin distribution,      |
//|   POC/VAH/VAL identification, and HVN/LVN detection.            |
//|                                                                  |
//| Functions:                                                       |
//|   - CalculateCurrentVolumeProfile(lookbackBars)                  |
//|   - CalculateValueArea(&profile)                                |
//|   - IdentifyVolumeNodes(&profile, hvnThreshold, lvnThreshold)   |
//|                                                                  |
//+------------------------------------------------------------------+

#ifndef __VOLUMEPROFILE_MQH__
#define __VOLUMEPROFILE_MQH__

// ==================== CONSTANTS ====================

#define VOLUME_BINS 400
#define VALUE_AREA_PERCENT 0.70  // 70% cumulative volume
#define HVN_MULTIPLIER 1.3       // D-02: locked
#define LVN_MULTIPLIER 0.7       // D-02: locked

// ==================== DATA STRUCTURES ====================

struct VolumeNode {
    double price;
    double volume;
};

struct VolumeProfile {
    double volumeArray[VOLUME_BINS];    // 400-bin distribution
    double pocPrice;                    // Point of Control price
    double pocVolume;                   // Volume at POC
    double vahPrice;                    // Value Area High
    double valPrice;                    // Value Area Low
    double binSize;                     // Price per bin
    double minPrice;                    // Minimum price in lookback
    double maxPrice;                    // Maximum price in lookback
    int    pocBinIndex;                 // Bin index of POC
    int    hvnCount;                    // Number of HVN zones
    int    lvnCount;                    // Number of LVN zones
    VolumeNode hvnArray[50];            // High Volume Node array
    VolumeNode lvnArray[50];            // Low Volume Node array
};

// ==================== FUNCTION DECLARATIONS ====================

// Calculate 400-bin volume distribution (REQ-001, REQ-008)
VolumeProfile CalculateCurrentVolumeProfile(int lookbackBars);

// Calculate POC and VAH/VAL boundaries (REQ-002, REQ-003, REQ-004)
void CalculateValueArea(VolumeProfile &profile);

// Identify High/Low Volume Nodes (REQ-005, REQ-006)
void IdentifyVolumeNodes(VolumeProfile &profile, double hvnThreshold, double lvnThreshold);

// ==================== FUNCTION IMPLEMENTATIONS ====================

//+------------------------------------------------------------------+
//| Calculate 400-bin volume distribution (REQ-001, REQ-008)         |
//| Implementation per D-01: Proportional-to-range proration         |
//+------------------------------------------------------------------+
VolumeProfile CalculateCurrentVolumeProfile(int lookbackBars)
{
    VolumeProfile profile;

    // Step 1: Find price range from lookback period
    double minPrice = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, lookbackBars, 0);
    double maxPrice = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, lookbackBars, 0);

    if (maxPrice <= minPrice)
    {
        LogError("Invalid price range for volume profile");
        return profile;  // Return empty profile
    }

    // Calculate bin size
    double binSize = (maxPrice - minPrice) / VOLUME_BINS;

    // Store metadata
    profile.minPrice = minPrice;
    profile.maxPrice = maxPrice;
    profile.binSize = binSize;

    // Step 2: Initialize volume array to zero
    ArrayInitialize(profile.volumeArray, 0);

    // Step 3: Iterate through lookback bars and prorate volume
    for (int i = 0; i < lookbackBars; i++)
    {
        double high = iHigh(Symbol(), PERIOD_CURRENT, i);
        double low = iLow(Symbol(), PERIOD_CURRENT, i);
        double close = iClose(Symbol(), PERIOD_CURRENT, i);
        long volume = iVolume(Symbol(), PERIOD_CURRENT, i);

        if (volume <= 0)
            continue;  // Skip bars with zero volume

        double range = high - low;

        // Multi-level candle: distribute volume proportionally across price range
        if (range > binSize)
        {
            // Calculate how many bins this candle spans
            int numBins = (int)(range / binSize) + 1;
            if (numBins > VOLUME_BINS)
                numBins = VOLUME_BINS;  // Safety cap

            double volumePerBin = (double)volume / numBins;

            // Iterate from low to high in bin steps
            for (double price = low; price <= high && price <= maxPrice; price += binSize)
            {
                int binIdx = (int)((price - minPrice) / binSize);
                if (binIdx >= 0 && binIdx < VOLUME_BINS)
                {
                    profile.volumeArray[binIdx] += volumePerBin;
                }
            }
        }
        else
        {
            // Doji or flat candle: all volume goes to close price bin
            int binIdx = (int)((close - minPrice) / binSize);
            if (binIdx >= 0 && binIdx < VOLUME_BINS)
            {
                profile.volumeArray[binIdx] += volume;
            }
        }
    }

    // Step 4: Validation - Check volume distribution integrity
    double binSum = 0;
    long rawTotal = 0;

    for (int i = 0; i < lookbackBars; i++)
        rawTotal += iVolume(Symbol(), PERIOD_CURRENT, i);

    for (int i = 0; i < VOLUME_BINS; i++)
        binSum += profile.volumeArray[i];

    if (rawTotal > 0)
    {
        double variance = MathAbs(binSum - rawTotal) / rawTotal;
        if (variance > 0.01)  // >1% variance
        {
            LogAlert("WARNING", StringFormat("Volume distribution variance %.2f%% > 1%%, sum=%.0f, total=%d",
                variance * 100, binSum, rawTotal));
        }
        else if (variance > 0.001)  // >0.1% variance
        {
            LogAlert("WARNING", StringFormat("Volume distribution variance %.3f%% (minor)", variance * 100));
        }
    }

    return profile;
}

//+------------------------------------------------------------------+
//| Calculate POC and VAH/VAL boundaries (REQ-002, REQ-003, REQ-004) |
//| POC = single price bin with max volume                            |
//| VAH/VAL = 70% cumulative volume expanding from POC                |
//+------------------------------------------------------------------+
void CalculateValueArea(VolumeProfile &profile)
{
    if (profile.binSize <= 0)
    {
        LogError("Volume profile not calculated before VAH/VAL");
        return;
    }

    // Step 1: Identify POC (Point of Control)
    // POC = price bin with highest accumulated volume
    double maxVol = 0;
    int pocIdx = 0;

    for (int i = 0; i < VOLUME_BINS; i++)
    {
        if (profile.volumeArray[i] > maxVol)
        {
            maxVol = profile.volumeArray[i];
            pocIdx = i;
        }
    }

    // Convert bin index to price (use center of bin)
    profile.pocBinIndex = pocIdx;
    profile.pocPrice = profile.minPrice +
                       (pocIdx * profile.binSize) +
                       (profile.binSize / 2.0);
    profile.pocVolume = maxVol;

    // Step 2: Calculate VAH/VAL (70% Value Area expansion)
    // Calculate total volume and target threshold
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += profile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for VAH/VAL calculation");
        return;
    }

    double targetVol = totalVol * VALUE_AREA_PERCENT;  // 70% threshold

    // Expand outward from POC until 70% cumulative volume reached
    double cumulativeVol = profile.volumeArray[profile.pocBinIndex];
    int offset = 0;
    int maxOffset = 200;  // Safety: don't expand > 50% of bins

    while (cumulativeVol < targetVol && offset < maxOffset)
    {
        offset++;

        // Add bin above POC (higher price)
        if (profile.pocBinIndex + offset < VOLUME_BINS)
        {
            cumulativeVol += profile.volumeArray[profile.pocBinIndex + offset];
        }

        // Add bin below POC (lower price)
        if (profile.pocBinIndex - offset >= 0)
        {
            cumulativeVol += profile.volumeArray[profile.pocBinIndex - offset];
        }
    }

    // Step 3: Calculate VAH and VAL prices
    int vahBinIndex = profile.pocBinIndex + offset;
    int valBinIndex = profile.pocBinIndex - offset;

    // Clamp to valid range
    if (vahBinIndex >= VOLUME_BINS)
        vahBinIndex = VOLUME_BINS - 1;
    if (valBinIndex < 0)
        valBinIndex = 0;

    profile.vahPrice = profile.minPrice +
                       (vahBinIndex * profile.binSize);
    profile.valPrice = profile.minPrice +
                       (valBinIndex * profile.binSize);

    // Step 4: Validation - Check Value Area width is reasonable
    double vaWidth = profile.vahPrice - profile.valPrice;
    if (vaWidth < profile.binSize)
    {
        LogAlert("WARNING", StringFormat("VA width %.5f < bin size %.5f",
            vaWidth, profile.binSize));
    }

    // Log POC/VAH/VAL prices for audit trail
    LogAlert("VA_CALC", StringFormat("POC=%.5f VAH=%.5f VAL=%.5f width_pips=%.2f",
        profile.pocPrice,
        profile.vahPrice,
        profile.valPrice,
        (profile.vahPrice - profile.valPrice) / Point));
}

//+------------------------------------------------------------------+
//| Identify High/Low Volume Nodes (REQ-005, REQ-006)               |
//| HVN = local peaks > 1.3x average volume (locked per D-02)       |
//| LVN = local valleys < 0.7x average volume (locked per D-02)    |
//+------------------------------------------------------------------+
void IdentifyVolumeNodes(VolumeProfile &profile, double hvnThreshold, double lvnThreshold)
{
    if (profile.pocPrice <= 0)
    {
        LogError("POC not calculated before node identification");
        return;
    }

    // Step 1: Calculate average volume per bin
    double totalVol = 0;
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        totalVol += profile.volumeArray[i];
    }

    if (totalVol <= 0)
    {
        LogError("Total volume <= 0 for node identification");
        return;
    }

    double avgVolume = totalVol / VOLUME_BINS;

    // Step 2: Apply provided thresholds (or use defaults)
    double hvnThresholdActual = (hvnThreshold > 0) ? hvnThreshold : (avgVolume * HVN_MULTIPLIER);
    double lvnThresholdActual = (lvnThreshold > 0) ? lvnThreshold : (avgVolume * LVN_MULTIPLIER);

    // Step 3: Reset arrays and counters
    profile.hvnCount = 0;
    profile.lvnCount = 0;
    // Zero out HVN and LVN arrays
    for (int j = 0; j < 50; j++)
    {
        profile.hvnArray[j].price = 0;
        profile.hvnArray[j].volume = 0;
        profile.lvnArray[j].price = 0;
        profile.lvnArray[j].volume = 0;
    }

    // Step 4: Iterate and classify bins as HVN or LVN
    for (int i = 0; i < VOLUME_BINS; i++)
    {
        double binVolume = profile.volumeArray[i];
        double binPrice = profile.minPrice + (i * profile.binSize);

        // HVN: local peaks > 1.3x average
        if (binVolume > hvnThresholdActual)
        {
            if (profile.hvnCount < 50)  // Max 50 HVN clusters
            {
                profile.hvnArray[profile.hvnCount].price = binPrice;
                profile.hvnArray[profile.hvnCount].volume = binVolume;
                profile.hvnCount++;
            }
        }

        // LVN: local valleys < 0.7x average
        if (binVolume < lvnThresholdActual)
        {
            if (profile.lvnCount < 50)  // Max 50 LVN clusters
            {
                profile.lvnArray[profile.lvnCount].price = binPrice;
                profile.lvnArray[profile.lvnCount].volume = binVolume;
                profile.lvnCount++;
            }
        }
    }

    // Step 5: Validation - sanity-check cluster counts
    if (profile.hvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("HVN count %d exceeds max (50); truncated",
            profile.hvnCount));
        profile.hvnCount = 50;
    }

    if (profile.lvnCount > 50)
    {
        LogAlert("WARNING", StringFormat("LVN count %d exceeds max (50); truncated",
            profile.lvnCount));
        profile.lvnCount = 50;
    }
}

#endif  // __VOLUMEPROFILE_MQH__
