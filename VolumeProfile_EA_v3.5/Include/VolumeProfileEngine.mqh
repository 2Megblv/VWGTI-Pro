//+------------------------------------------------------------------+
//| VolumeProfileEngine.mqh - Robust Volume Profile Calculation
//|
//| Encapsulates all volume profile calculations with:
//| - Immutable results after calculation
//| - Built-in validation
//| - Multi-timeframe support via SetTimeframe()
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
    bool              isCalculated;
    datetime          lastCalculationTime;
    int               lastLookbackBars;
    ENUM_TIMEFRAMES   m_timeframe;   // Configurable timeframe (default PERIOD_CURRENT)

    // ==================== PRIVATE VALIDATION METHODS ====================

    bool ValidateDistribution() {
        if (totalVolume <= 0) {
            Print("[ERROR] Volume profile: no bars with volume in lookback range");
            return false;
        }
        return true;
    }

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

    void CalculatePOC() {
        pocPrice  = 0;
        pocVolume = 0;

        for (int i = 0; i < VOLUME_BINS; i++) {
            if (volumeArray[i] > pocVolume) {
                pocVolume = volumeArray[i];
                pocPrice  = minPrice + (i * binSize) + (binSize / 2.0);
            }
        }
    }

    void CalculateValueArea() {
        if (pocVolume <= 0) return;

        double targetVolume    = totalVolume * 0.70;
        double cumulativeVolume = pocVolume;
        int    pocBinIndex      = (int)((pocPrice - minPrice) / binSize);
        int    offset           = 0;
        int    maxOffset        = 200;

        while (cumulativeVolume < targetVolume && offset < maxOffset) {
            offset++;
            if (pocBinIndex + offset < VOLUME_BINS)
                cumulativeVolume += volumeArray[pocBinIndex + offset];
            if (pocBinIndex - offset >= 0)
                cumulativeVolume += volumeArray[pocBinIndex - offset];
        }

        int vahBinIndex = pocBinIndex + offset;
        int valBinIndex = pocBinIndex - offset;

        if (vahBinIndex >= VOLUME_BINS) vahBinIndex = VOLUME_BINS - 1;
        if (valBinIndex < 0)            valBinIndex = 0;

        vahPrice = minPrice + (vahBinIndex * binSize);
        valPrice = minPrice + (valBinIndex * binSize);
    }

public:
    // ==================== PUBLIC INTERFACE ====================

    VolumeProfileEngine() : isCalculated(false), hvnCount(0), lvnCount(0),
                            pocPrice(0), pocVolume(0), vahPrice(0), valPrice(0),
                            binSize(0), minPrice(0), maxPrice(0), totalVolume(0),
                            lastCalculationTime(0), lastLookbackBars(0),
                            m_timeframe(PERIOD_CURRENT) {
        ArrayInitialize(volumeArray, 0);
        ArrayInitialize(priceArray,  0);
        VolumeNode emptyNode;
        emptyNode.price  = 0;
        emptyNode.volume = 0;
        for (int i = 0; i < MAX_NODES; i++) {
            hvnArray[i] = emptyNode;
            lvnArray[i] = emptyNode;
        }
    }

    // Set which timeframe this engine operates on (call before Calculate)
    void SetTimeframe(ENUM_TIMEFRAMES tf) {
        m_timeframe  = tf;
        isCalculated = false;  // Invalidate any prior result on TF change
    }

    ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }

    //+------------------------------------------------------------------+
    //| Main calculation method
    //| Returns: true if calculation successful and valid
    //+------------------------------------------------------------------+
    bool Calculate(int lookbackBars) {
        int availableBars = Bars(Symbol(), m_timeframe);
        if (lookbackBars <= 0 || lookbackBars > availableBars) {
            Print("[ERROR] Invalid lookback period: ", lookbackBars,
                  " (available: ", availableBars, " on TF=", EnumToString(m_timeframe), ")");
            return false;
        }

        ArrayInitialize(volumeArray, 0);
        hvnCount    = 0;
        lvnCount    = 0;
        totalVolume = 0;

        int lowestIdx  = iLowest (Symbol(), m_timeframe, MODE_LOW,  lookbackBars, 0);
        int highestIdx = iHighest(Symbol(), m_timeframe, MODE_HIGH, lookbackBars, 0);

        minPrice = iLow (Symbol(), m_timeframe, lowestIdx);
        maxPrice = iHigh(Symbol(), m_timeframe, highestIdx);

        if (maxPrice <= minPrice) {
            Print("[ERROR] Invalid price range on TF=", EnumToString(m_timeframe));
            return false;
        }

        binSize = (maxPrice - minPrice) / VOLUME_BINS;

        for (int i = 0; i < lookbackBars; i++) {
            double high   = iHigh  (Symbol(), m_timeframe, i);
            double low    = iLow   (Symbol(), m_timeframe, i);
            double close  = iClose (Symbol(), m_timeframe, i);
            long   volume = (long)iTickVolume(Symbol(), m_timeframe, i);

            if (volume <= 0) continue;

            totalVolume += (double)volume;

            double range = high - low;

            if (range > binSize) {
                int lowBin  = (int)((low  - minPrice) / binSize);
                int highBin = (int)((high - minPrice) / binSize);

                if (lowBin  < 0)           lowBin  = 0;
                if (highBin >= VOLUME_BINS) highBin = VOLUME_BINS - 1;

                int numBins = highBin - lowBin + 1;
                if (numBins <= 0) numBins = 1;

                double volumePerBin = (double)volume / numBins;

                for (int bin = lowBin; bin <= highBin; bin++) {
                    volumeArray[bin] += volumePerBin;
                }
            } else {
                int bin = (int)((close - minPrice) / binSize);
                if (bin >= 0 && bin < VOLUME_BINS) {
                    volumeArray[bin] += (double)volume;
                }
            }
        }

        if (!ValidateDistribution()) return false;

        CalculatePOC();
        CalculateValueArea();

        if (!ValidateValueArea()) return false;

        isCalculated         = true;
        lastCalculationTime  = TimeCurrent();
        lastLookbackBars     = lookbackBars;

        return true;
    }

    // ==================== GETTERS ====================

    double GetPOC()      const { return pocPrice;  }
    double GetVAH()      const { return vahPrice;  }
    double GetVAL()      const { return valPrice;  }
    double GetMinPrice() const { return minPrice;  }
    double GetMaxPrice() const { return maxPrice;  }
    double GetBinSize()  const { return binSize;   }
    int    GetHVNCount() const { return hvnCount;  }
    int    GetLVNCount() const { return lvnCount;  }
    bool   IsValid()     const { return isCalculated; }

    //+------------------------------------------------------------------+
    //| Identify High/Low Volume Nodes
    //+------------------------------------------------------------------+
    bool IdentifyNodes(double hvnMult = 1.3, double lvnMult = 0.7) {
        if (!isCalculated) {
            Print("[ERROR] Profile not calculated before IdentifyNodes");
            return false;
        }

        hvnCount = 0;
        lvnCount = 0;

        double avgVolume          = totalVolume / VOLUME_BINS;
        double hvnThresholdActual = avgVolume * hvnMult;
        double lvnThresholdActual = avgVolume * lvnMult;

        for (int i = 0; i < VOLUME_BINS; i++) {
            double binPrice = minPrice + (i * binSize);

            if (volumeArray[i] > hvnThresholdActual) {
                if (hvnCount < MAX_NODES) {
                    hvnArray[hvnCount].price  = binPrice;
                    hvnArray[hvnCount].volume = volumeArray[i];
                    hvnCount++;
                }
            }

            if (volumeArray[i] < lvnThresholdActual) {
                if (lvnCount < MAX_NODES) {
                    lvnArray[lvnCount].price  = binPrice;
                    lvnArray[lvnCount].volume = volumeArray[i];
                    lvnCount++;
                }
            }
        }

        if (hvnCount >= MAX_NODES)
            Print("[WARNING] HVN node cap (", MAX_NODES, ") reached; raise MAX_NODES if needed");
        if (lvnCount >= MAX_NODES)
            Print("[WARNING] LVN node cap (", MAX_NODES, ") reached; raise MAX_NODES if needed");

        return true;
    }

    double GetHVNPrice(int index) const {
        if (index < 0 || index >= hvnCount) return 0;
        return hvnArray[index].price;
    }

    double GetLVNPrice(int index) const {
        if (index < 0 || index >= lvnCount) return 0;
        return lvnArray[index].price;
    }
};

#endif // __VOLUME_PROFILE_ENGINE_MQH__
