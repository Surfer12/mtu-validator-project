package com.network.mtu.core;

/**
 * Functional interface for extracting and validating MTU (Maximum Transmission Unit) values
 * from different network configuration types.
 *
 * @param <T> The type of network configuration from which to extract MTU values
 * @since 1.0
 */
@FunctionalInterface
public interface MtuExtractor<T> {
    
    /**
     * Extracts the MTU value from the given network configuration.
     *
     * @param config The network configuration object from which to extract the MTU
     * @return The extracted MTU value as an integer
     * @throws MtuExtractionException if the MTU cannot be extracted from the configuration
     */
    int extractMtu(T config) throws MtuExtractionException;
    
    /**
     * Gets metadata about this extractor implementation.
     *
     * @return The extractor metadata
     */
    default ExtractorMetadata getMetadata() {
        return ExtractorMetadata.builder()
            .name("Unknown Extractor")
            .description("No description available")
            .author("Unknown")
            .build();
    }
    
    /**
     * Default method to validate the extracted MTU value against common network standards.
     *
     * @param mtuValue The MTU value to validate
     * @return true if the MTU value is within standard ranges, false otherwise
     */
    default boolean isStandardMtu(int mtuValue) {
        return mtuValue >= 68 && mtuValue <= 9000;
    }
}