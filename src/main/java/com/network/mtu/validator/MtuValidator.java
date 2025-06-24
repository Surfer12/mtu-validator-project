package com.network.mtu.validator;

import com.network.mtu.core.MtuExtractor;
import com.network.mtu.core.MtuExtractionException;
import com.network.mtu.core.MtuExtractionException.ErrorCode;

import java.time.Instant;
import java.util.List;
import java.util.function.Predicate;

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
    
    /**
     * Network protocols supported by the validator.
     */
    public enum Protocol {
        IPV4("IPv4", 68, 65535),
        IPV6("IPv6", 1280, 65535),
        ETHERNET("Ethernet", 64, 9000),
        PPP("PPP", 64, 1500);
        
        private final String displayName;
        private final int minMtu;
        private final int maxMtu;
        
        Protocol(String displayName, int minMtu, int maxMtu) {
            this.displayName = displayName;
            this.minMtu = minMtu;
            this.maxMtu = maxMtu;
        }
        
        public String getDisplayName() {
            return displayName;
        }
        
        public int getMinMtu() {
            return minMtu;
        }
        
        public int getMaxMtu() {
            return maxMtu;
        }
    }
    
    /**
     * Network types based on MTU size.
     */
    public enum NetworkType {
        STANDARD_ETHERNET("Standard Ethernet", 1500),
        JUMBO_FRAME("Jumbo Frame", 9000),
        IPV6_MINIMUM("IPv6 Minimum", 1280),
        PPPOE("PPPoE", 1492),
        CUSTOM("Custom", -1);
        
        private final String displayName;
        private final int typicalMtu;
        
        NetworkType(String displayName, int typicalMtu) {
            this.displayName = displayName;
            this.typicalMtu = typicalMtu;
        }
        
        public String getDisplayName() {
            return displayName;
        }
        
        public int getTypicalMtu() {
            return typicalMtu;
        }
    }
    
    private final int minMtu;
    private final int maxMtu;
    private final Protocol protocol;
    private final Predicate<Integer> customValidator;
    private final boolean strictMode;
    private final String validatorName;
    
    private MtuValidator(Builder<T> builder) {
        this.minMtu = builder.minMtu;
        this.maxMtu = builder.maxMtu;
        this.protocol = builder.protocol;
        this.customValidator = builder.customValidator;
        this.strictMode = builder.strictMode;
        this.validatorName = builder.validatorName;
    }
    
    /**
     * Creates a builder for MtuValidator.
     *
     * @param <T> The configuration type
     * @return A new builder
     */
    public static <T> Builder<T> builder() {
        return new Builder<>();
    }
    
    /**
     * Creates a standard Ethernet validator.
     *
     * @param <T> The configuration type
     * @return A validator for standard Ethernet networks
     */
    public static <T> MtuValidator<T> forEthernet() {
        return builder()
            .minMtu(64)
            .maxMtu(ETHERNET_MTU)
            .protocol(Protocol.ETHERNET)
            .validatorName("Standard Ethernet Validator")
            .build();
    }
    
    /**
     * Creates a jumbo frame validator.
     *
     * @param <T> The configuration type
     * @return A validator for jumbo frame networks
     */
    public static <T> MtuValidator<T> forJumboFrames() {
        return builder()
            .minMtu(1500)
            .maxMtu(JUMBO_FRAME_MTU)
            .protocol(Protocol.ETHERNET)
            .validatorName("Jumbo Frame Validator")
            .build();
    }
    
    /**
     * Creates an IPv6 validator.
     *
     * @param <T> The configuration type
     * @return A validator for IPv6 networks
     */
    public static <T> MtuValidator<T> forIpv6() {
        return builder()
            .minMtu(IPV6_MINIMUM_MTU)
            .maxMtu(65535)
            .protocol(Protocol.IPV6)
            .validatorName("IPv6 Validator")
            .build();
    }
    
    /**
     * Validates if the given MTU size is within the acceptable range
     * @param mtuSize MTU size to validate
     * @return true if MTU is valid, false otherwise
     */
    public boolean isValidMtu(int mtuSize) {
        boolean inRange = mtuSize >= minMtu && mtuSize <= maxMtu;
        if (!inRange) return false;
        
        if (customValidator != null) {
            return customValidator.test(mtuSize);
        }
        
        return true;
    }
    
    /**
     * Validates a direct MTU value and returns a detailed result.
     *
     * @param mtuValue The MTU value to validate
     * @return ValidationResult with detailed information
     */
    public ValidationResult validateMtuValue(int mtuValue) {
        if (isValidMtu(mtuValue)) {
            return ValidationResult.builder()
                .valid(true)
                .message("MTU value " + mtuValue + " is valid")
                .mtuValue(mtuValue)
                .networkType(determineNetworkType(mtuValue))
                .validatorName(validatorName)
                .timestamp(Instant.now())
                .build();
        } else {
            return ValidationResult.builder()
                .valid(false)
                .message(String.format("MTU value %d is invalid (range: %d-%d)", mtuValue, minMtu, maxMtu))
                .mtuValue(mtuValue)
                .networkType(determineNetworkType(mtuValue))
                .validatorName(validatorName)
                .timestamp(Instant.now())
                .recommendations(List.of(
                    "Ensure MTU is between " + minMtu + " and " + maxMtu,
                    "Check network interface configuration",
                    "Verify protocol requirements"
                ))
                .build();
        }
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
            return validateMtuValue(mtuSize);
        } catch (MtuExtractionException e) {
            return ValidationResult.builder()
                .valid(false)
                .message("Failed to validate MTU: " + e.getMessage())
                .validatorName(validatorName)
                .timestamp(Instant.now())
                .errorCode(e.getErrorCode())
                .recommendations(List.of(
                    "Check configuration format",
                    "Verify MTU value exists in configuration",
                    "Ensure proper data types"
                ))
                .build();
        }
    }
    
    /**
     * Determines the network type based on MTU value.
     *
     * @param mtuValue The MTU value
     * @return The network type
     */
    private NetworkType determineNetworkType(int mtuValue) {
        if (mtuValue == ETHERNET_MTU) return NetworkType.STANDARD_ETHERNET;
        if (mtuValue == JUMBO_FRAME_MTU) return NetworkType.JUMBO_FRAME;
        if (mtuValue == IPV6_MINIMUM_MTU) return NetworkType.IPV6_MINIMUM;
        if (mtuValue == PPPOE_MTU) return NetworkType.PPPOE;
        return NetworkType.CUSTOM;
    }
    
    /**
     * Builder for MtuValidator.
     *
     * @param <T> The configuration type
     */
    public static class Builder<T> {
        private int minMtu = 64;
        private int maxMtu = 9000;
        private Protocol protocol = Protocol.ETHERNET;
        private Predicate<Integer> customValidator;
        private boolean strictMode = false;
        private String validatorName = "MTU Validator";
        
        public Builder<T> minMtu(int minMtu) {
            this.minMtu = minMtu;
            return this;
        }
        
        public Builder<T> maxMtu(int maxMtu) {
            this.maxMtu = maxMtu;
            return this;
        }
        
        public Builder<T> protocol(Protocol protocol) {
            this.protocol = protocol;
            return this;
        }
        
        public Builder<T> customValidator(Predicate<Integer> customValidator) {
            this.customValidator = customValidator;
            return this;
        }
        
        public Builder<T> strictMode(boolean strictMode) {
            this.strictMode = strictMode;
            return this;
        }
        
        public Builder<T> validatorName(String validatorName) {
            this.validatorName = validatorName;
            return this;
        }
        
        public MtuValidator<T> build() {
            if (minMtu <= 0 || maxMtu <= 0 || minMtu > maxMtu) {
                throw new IllegalArgumentException("Invalid MTU range");
            }
            return new MtuValidator<>(this);
        }
    }
    
    /**
     * Value class to hold validation results
     */
    public static class ValidationResult {
        private final boolean valid;
        private final String message;
        private final Integer mtuValue;
        private final NetworkType networkType;
        private final List<String> recommendations;
        private final String validatorName;
        private final Instant timestamp;
        private final ErrorCode errorCode;
        
        private ValidationResult(Builder builder) {
            this.valid = builder.valid;
            this.message = builder.message;
            this.mtuValue = builder.mtuValue;
            this.networkType = builder.networkType;
            this.recommendations = List.copyOf(builder.recommendations);
            this.validatorName = builder.validatorName;
            this.timestamp = builder.timestamp;
            this.errorCode = builder.errorCode;
        }
        
        public boolean isValid() {
            return valid;
        }
        
        public String getMessage() {
            return message;
        }
        
        public Integer getMtuValue() {
            return mtuValue;
        }
        
        public NetworkType getNetworkType() {
            return networkType;
        }
        
        public List<String> getRecommendations() {
            return recommendations;
        }
        
        public String getValidatorName() {
            return validatorName;
        }
        
        public Instant getTimestamp() {
            return timestamp;
        }
        
        public ErrorCode getErrorCode() {
            return errorCode;
        }
        
        /**
         * Builder for ValidationResult.
         */
        public static class Builder {
            private boolean valid;
            private String message;
            private Integer mtuValue;
            private NetworkType networkType;
            private List<String> recommendations = List.of();
            private String validatorName;
            private Instant timestamp;
            private ErrorCode errorCode;
            
            public Builder valid(boolean valid) {
                this.valid = valid;
                return this;
            }
            
            public Builder message(String message) {
                this.message = message;
                return this;
            }
            
            public Builder mtuValue(Integer mtuValue) {
                this.mtuValue = mtuValue;
                return this;
            }
            
            public Builder networkType(NetworkType networkType) {
                this.networkType = networkType;
                return this;
            }
            
            public Builder recommendations(List<String> recommendations) {
                this.recommendations = recommendations;
                return this;
            }
            
            public Builder validatorName(String validatorName) {
                this.validatorName = validatorName;
                return this;
            }
            
            public Builder timestamp(Instant timestamp) {
                this.timestamp = timestamp;
                return this;
            }
            
            public Builder errorCode(ErrorCode errorCode) {
                this.errorCode = errorCode;
                return this;
            }
            
            public ValidationResult build() {
                return new ValidationResult(this);
            }
        }
        
        /**
         * Creates a new builder for ValidationResult.
         *
         * @return A new builder
         */
        public static Builder builder() {
            return new Builder();
        }
    }
}