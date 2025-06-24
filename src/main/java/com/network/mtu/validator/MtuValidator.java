/**
 * Generic MTU validator that can work with different network protocols and configurations.
 * @param <T> The type of network configuration being validated
 */
public class MtuValidator<T> {
    
    // Common MTU size constants
    public static final int ETHERNET_MTU = 1500;
    public static final int JUMBO_FRAME_MTU = 9000;
    public static final int IPV6_MINIMUM_MTU = 1280;
    public static final int PPPOE_MTU = 1492;
    
    private final int minMtu;
    private final int maxMtu;
    
    /**
     * Constructor with customizable MTU range
     * @param minMtu minimum allowed MTU value
     * @param maxMtu maximum allowed MTU value
     */
    public MtuValidator(int minMtu, int maxMtu) {
        if (minMtu <= 0 || maxMtu <= 0 || minMtu > maxMtu) {
            throw new IllegalArgumentException("Invalid MTU range");
        }
        this.minMtu = minMtu;
        this.maxMtu = maxMtu;
    }
    
    /**
     * Validates if the given MTU size is within the acceptable range
     * @param mtuSize MTU size to validate
     * @return true if MTU is valid, false otherwise
     */
    public boolean isValidMtu(int mtuSize) {
        return mtuSize >= minMtu && mtuSize <= maxMtu;
    }
    
    /**
     * Validates MTU configuration for a specific network type
     * @param config network configuration to validate
     * @param extractor function to extract MTU size from config
     * @return ValidationResult containing validation status and message
     */
    public ValidationResult validateConfig(T config, MtuExtractor<T> extractor) {
        try {
            int mtuSize = extractor.extractMtu(config);
            if (isValidMtu(mtuSize)) {
                return new ValidationResult(true, "MTU size " + mtuSize + " is valid");
            } else {
                return new ValidationResult(false, 
                    String.format("MTU size %d is outside valid range [%d-%d]", 
                        mtuSize, minMtu, maxMtu));
            }
        } catch (MtuExtractionException e) {
            return new ValidationResult(false, "Failed to validate MTU: " + e.getMessage());
        }
    }
    
    /**
     * Value class to hold validation results
     */
    public static class ValidationResult {
        private final boolean valid;
        private final String message;
        
        public ValidationResult(boolean valid, String message) {
            this.valid = valid;
            this.message = message;
        }
        
        public boolean isValid() {
            return valid;
        }
        
        public String getMessage() {
            return message;
        }
    }
}