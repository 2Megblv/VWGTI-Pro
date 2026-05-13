#property copyright "VWGTI-Pro v3.0"
#property version   "3.0"
#property strict

//+------------------------------------------------------------------+
//| VolumeProfileEngine.mqh - Robust Volume Profile Calculation
//| 
//| Encapsulates all volume profile calculations with:
//| - Immutable results after calculation
//| - Built-in validation
//| - Reusable for multi-timeframe analysis
//+------------------------------------------------------------------+

#ifndef __VOLUME_PROFILE_ENGINE_MQH__
#define __VOLUME_PROFILE_ENGINE_MQH__

#define VOLUME_BINS 400
#define MAX_NODES 50

class VolumeProfileEngine {
private:
    // ==================== INTERNAL STATE ====================
    double     volumeArray[VOLUME_BINS];
    double     priceArray[VOLUME_BINS];
    
    struct VolumeNode {
        double price;
        double volume;
    };
    
    VolumeNode hvnArray[MAX_NODES];
    VolumeNode lvnArray[MAX_NODES];
    int        hvnCount;
    int        lvnCount;
    
    // POC/VAH/VAL results
    double     pocPrice;
    double     pocVolume;
    double     vahPrice;
    double     valPrice;
    
    // Metadata
    double     binSize;
    double     minPrice;
    double     maxPrice;
    double     totalVolume;
    
    // State management
    bool       isCalculated;
    datetime   lastCalculationTime;
    int        lastLookbackBars;
    
    // ==================== PRIVATE VALIDATION METHODS ====================
    
    //+------------------------------------------------------------------+
    //| Validate volume distribution integrity
    //+------------------------------------------------------------------+
    bool ValidateDistribution(int lookbackBars) {
        if (totalVolume <= 0) {
            Print("[ERROR] Total volume is zero");
            return false;
        }
        
        // Calculate raw total from bars
        long rawTotal = 0;
        for (int i = 0; i < lookbackBars; i++) {
            rawTotal += (long)iVolume(Symbol(), PERIOD_CURRENT, i);
        }
        
        if (rawTotal <= 0) {
            Print("[WARNING] No volume data available (live bar)");
            return true;  // OK - incomplete data
        }
        
        // Check variance
        double variance = MathAbs(totalVolume - rawTotal) / rawTotal;
        if (variance > 0.01) {
            Print("[ERROR] Volume variance ", StringFormat("%.2f%%", variance * 100), " > 1%");
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Validate POC/VAH/VAL ranges
    //+------------------------------------------------------------------+
    bool ValidateValueArea() {
        if (pocPrice <= minPrice || pocPrice >= maxPrice) {
            Print("[ERROR] POC outside price range");
            return false;
        }
        
        if (vahPrice <= valPrice) {
            Print("[ERROR] VAH <= VAL (invalid value area)");
            return false;
        }
        
        double vaWidth = vahPrice - valPrice;
        if (vaWidth < binSize) {
            Print("[WARNING] VA width < bin size");
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Point of Control (POC)
    //+------------------------------------------------------------------+
    void CalculatePOC() {
        pocPrice = 0;
        pocVolume = 0;
        
        for (int i = 0; i < VOLUME_BINS; i++) {
            if (volumeArray[i] > pocVolume) {
                pocVolume = volumeArray[i];
                pocPrice = minPrice + (i * binSize) + (binSize / 2.0);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Value Area High/Low (70% cumulative)
    //+------------------------------------------------------------------+
    void CalculateValueArea() {
        if (pocVolume <= 0) return;
        
        double targetVolume = totalVolume * 0.70;  // 70% threshold
        double cumulativeVolume = pocVolume;
        int pocBinIndex = (int)((pocPrice - minPrice) / binSize);
        int offset = 0;
        int maxOffset = 200;
        
        // Expand outward from POC
        while (cumulativeVolume < targetVolume && offset < maxOffset) {
            offset++;
            
            // Add higher price level
            if (pocBinIndex + offset < VOLUME_BINS) {
                cumulativeVolume += volumeArray[pocBinIndex + offset];
            }
            
            // Add lower price level
            if (pocBinIndex - offset >= 0) {
                cumulativeVolume += volumeArray[pocBinIndex - offset];
            }
        }
        
        // Convert to prices
        int vahBinIndex = pocBinIndex + offset;
        int valBinIndex = pocBinIndex - offset;
        
        if (vahBinIndex >= VOLUME_BINS) vahBinIndex = VOLUME_BINS - 1;
        if (valBinIndex < 0) valBinIndex = 0;
        
        vahPrice = minPrice + (vahBinIndex * binSize);
        valPrice = minPrice + (valBinIndex * binSize);
    }
    
public:
    // ==================== PUBLIC INTERFACE ====================
    
    VolumeProfileEngine() : isCalculated(false), hvnCount(0), lvnCount(0), 
                            pocPrice(0), vahPrice(0), valPrice(0) {
        ArrayInitialize(volumeArray, 0);
        VolumeNode emptyNode;
        emptyNode.price = 0;
        emptyNode.volume = 0;
        for(int i = 0; i < MAX_NODES; i++) {
            hvnArray[i] = emptyNode;
            lvnArray[i] = emptyNode;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Main calculation method
    //| Returns: true if calculation successful and valid
    //+------------------------------------------------------------------+
    bool Calculate(int lookbackBars) {
        if (lookbackBars <= 0 || lookbackBars > Bars(Symbol(), PERIOD_CURRENT)) {
            Print("[ERROR] Invalid lookback period: ", lookbackBars);
            return false;
        }
        
        // Reset arrays
        ArrayInitialize(volumeArray, 0);
        hvnCount = 0;
        lvnCount = 0;
        totalVolume = 0;
        
        // Find price range
        int lowestIdx = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, lookbackBars, 0);
        int highestIdx = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, lookbackBars, 0);
        
        minPrice = iLow(Symbol(), PERIOD_CURRENT, lowestIdx);
        maxPrice = iHigh(Symbol(), PERIOD_CURRENT, highestIdx);
        
        if (maxPrice <= minPrice) {
            Print("[ERROR] Invalid price range");
            return false;
        }
        
        binSize = (maxPrice - minPrice) / VOLUME_BINS;
        
        // Distribute volume across bins
        for (int i = 0; i < lookbackBars; i++) {
            double high = iHigh(Symbol(), PERIOD_CURRENT, i);
            double low = iLow(Symbol(), PERIOD_CURRENT, i);
            double close = iClose(Symbol(), PERIOD_CURRENT, i);
            long volume = (long)iVolume(Symbol(), PERIOD_CURRENT, i);
            
            if (volume <= 0) continue;
            
            totalVolume += (double)volume;
            
            // Multi-level candle: prorate volume across price range
            double range = high - low;
            
            if (range > binSize) {
                int lowBin = (int)((low - minPrice) / binSize);
                int highBin = (int)((high - minPrice) / binSize);
                
                if (lowBin < 0) lowBin = 0;
                if (highBin >= VOLUME_BINS) highBin = VOLUME_BINS - 1;
                
                int numBins = highBin - lowBin + 1;
                if (numBins <= 0) numBins = 1;
                
                double volumePerBin = (double)volume / numBins;
                
                for (int bin = lowBin; bin <= highBin; bin++) {
                    volumeArray[bin] += volumePerBin;
                }
            } else {
                // Doji: all volume to close
                int bin = (int)((close - minPrice) / binSize);
                if (bin >= 0 && bin < VOLUME_BINS) {
                    volumeArray[bin] += (double)volume;
                }
            }
        }
        
        // Validate and calculate results
        if (!ValidateDistribution(lookbackBars)) {
            return false;
        }
        
        CalculatePOC();
        CalculateValueArea();
        
        if (!ValidateValueArea()) {
            return false;
        }
        
        isCalculated = true;
        lastCalculationTime = TimeCurrent();
        lastLookbackBars = lookbackBars;
        
        return true;
    }
    
    // ==================== GETTERS (IMMUTABLE AFTER CALCULATE) ====================
    
    double GetPOC() const { return pocPrice; }
    double GetVAH() const { return vahPrice; }
    double GetVAL() const { return valPrice; }
    double GetMinPrice() const { return minPrice; }
    double GetMaxPrice() const { return maxPrice; }
    double GetBinSize() const { return binSize; }
    int    GetHVNCount() const { return hvnCount; }
    int    GetLVNCount() const { return lvnCount; }
    bool   IsValid() const { return isCalculated; }
    
    //+------------------------------------------------------------------+
    //| Identify High/Low Volume Nodes
    //+------------------------------------------------------------------+
    bool IdentifyNodes(double hvnThreshold = 0, double lvnThreshold = 0) {
        if (!isCalculated) {
            Print("[ERROR] Profile not calculated");
            return false;
        }
        
        hvnCount = 0;
        lvnCount = 0;
        
        double avgVolume = totalVolume / VOLUME_BINS;
        double hvnThresholdActual = (hvnThreshold > 0) ? hvnThreshold : (avgVolume * 1.3);
        double lvnThresholdActual = (lvnThreshold > 0) ? lvnThreshold : (avgVolume * 0.7);
        
        for (int i = 0; i < VOLUME_BINS; i++) {
            double binPrice = minPrice + (i * binSize);
            
            if (volumeArray[i] > hvnThresholdActual && hvnCount < MAX_NODES) {
                hvnArray[hvnCount].price = binPrice;
                hvnArray[hvnCount].volume = volumeArray[i];
                hvnCount++;
            }
            
            if (volumeArray[i] < lvnThresholdActual && lvnCount < MAX_NODES) {
                lvnArray[lvnCount].price = binPrice;
                lvnArray[lvnCount].volume = volumeArray[i];
                lvnCount++;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get HVN price by index
    //+------------------------------------------------------------------+
    double GetHVNPrice(int index) const {
        if (index < 0 || index >= hvnCount) return 0;
        return hvnArray[index].price;
    }
    
    //+------------------------------------------------------------------+
    //| Get LVN price by index
    //+------------------------------------------------------------------+
    double GetLVNPrice(int index) const {
        if (index < 0 || index >= lvnCount) return 0;
        return lvnArray[index].price;
    }
};

#endif // __VOLUME_PROFILE_ENGINE_MQH__
