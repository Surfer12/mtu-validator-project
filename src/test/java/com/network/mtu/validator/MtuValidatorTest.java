package com.network.mtu.validator;

import com.network.mtu.core.MtuExtractor;
import com.network.mtu.core.MtuExtractionException;
import com.network.mtu.validator.MtuValidator.ValidationResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.*;

/**
 * Unit tests for MtuValidator.
 * 
 * @since 1.0.0
 */
@DisplayName("MTU Validator Tests")
class MtuValidatorTest {
    
    private MtuValidator<Integer> ethernetValidator;
    private MtuValidator<Integer> jumboValidator;
    private MtuValidator<Integer> ipv6Validator;
    
    @BeforeEach
    void setUp() {
        ethernetValidator = MtuValidator.forEthernet();
        jumboValidator = MtuValidator.forJumboFrames();
        ipv6Validator = MtuValidator.forIpv6();
    }
    
    @Test
    @DisplayName("Should validate standard Ethernet MTU values")
    void shouldValidateStandardEthernetMtu() {
        // Given
        int standardEthernetMtu = 1500;
        
        // When
        ValidationResult result = ethernetValidator.validateMtuValue(standardEthernetMtu);
        
        // Then
        assertThat(result.isValid()).isTrue();
        assertThat(result.getMtuValue()).isEqualTo(standardEthernetMtu);
        assertThat(result.getMessage()).contains("valid");
        assertThat(result.getNetworkType()).hasValue("Ethernet");
    }
    
    @Test
    @DisplayName("Should reject MTU values below minimum")
    void shouldRejectMtuBelowMinimum() {
        // Given
        int belowMinimumMtu = 50;
        
        // When
        ValidationResult result = ethernetValidator.validateMtuValue(belowMinimumMtu);
        
        // Then
        assertThat(result.isValid()).isFalse();
        assertThat(result.getMessage()).contains("invalid");
        assertThat(result.getMessage()).contains("below minimum");
    }
    
    @Test
    @DisplayName("Should reject MTU values above maximum")
    void shouldRejectMtuAboveMaximum() {
        // Given
        int aboveMaximumMtu = 10000;
        
        // When
        ValidationResult result = ethernetValidator.validateMtuValue(aboveMaximumMtu);
        
        // Then
        assertThat(result.isValid()).isFalse();
        assertThat(result.getMessage()).contains("invalid");
        assertThat(result.getMessage()).contains("above maximum");
    }
    
    @ParameterizedTest
    @ValueSource(ints = {68, 576, 1492, 1500})
    @DisplayName("Should validate common MTU values")
    void shouldValidateCommonMtuValues(int mtu) {
        // When
        ValidationResult result = ethernetValidator.validateMtuValue(mtu);
        
        // Then
        assertThat(result.isValid()).isTrue();
        assertThat(result.getMtuValue()).isEqualTo(mtu);
    }
    
    @Test
    @DisplayName("Should validate jumbo frame MTU")
    void shouldValidateJumboFrameMtu() {
        // Given
        int jumboMtu = 9000;
        
        // When
        ValidationResult result = jumboValidator.validateMtuValue(jumboMtu);
        
        // Then
        assertThat(result.isValid()).isTrue();
        assertThat(result.getNetworkType()).hasValue("Jumbo Frame");
        assertThat(result.getRecommendations()).isNotEmpty();
    }
    
    @Test
    @DisplayName("Should validate IPv6 minimum MTU")
    void shouldValidateIpv6MinimumMtu() {
        // Given
        int ipv6MinimumMtu = 1280;
        
        // When
        ValidationResult result = ipv6Validator.validateMtuValue(ipv6MinimumMtu);
        
        // Then
        assertThat(result.isValid()).isTrue();
        assertThat(result.getMtuValue()).isEqualTo(ipv6MinimumMtu);
    }
    
    @Test
    @DisplayName("Should reject IPv6 MTU below minimum")
    void shouldRejectIpv6MtuBelowMinimum() {
        // Given
        int belowIpv6Minimum = 1200;
        
        // When
        ValidationResult result = ipv6Validator.validateMtuValue(belowIpv6Minimum);
        
        // Then
        assertThat(result.isValid()).isFalse();
        assertThat(result.getMessage()).contains("invalid for protocol IPV6");
    }
    
    @Test
    @DisplayName("Should validate configuration with extractor")
    void shouldValidateConfigurationWithExtractor() throws MtuExtractionException {
        // Given
        Integer config = 1500;
        MtuExtractor<Integer> extractor = value -> value;
        
        // When
        ValidationResult result = ethernetValidator.validateConfig(config, extractor);
        
        // Then
        assertThat(result.isValid()).isTrue();
        assertThat(result.getMtuValue()).isEqualTo(1500);
    }
    
    @Test
    @DisplayName("Should handle extraction exception")
    void shouldHandleExtractionException() {
        // Given
        String config = "invalid";
        MtuExtractor<String> failingExtractor = value -> {
            throw new MtuExtractionException("Extraction failed");
        };
        
        // When
        ValidationResult result = ethernetValidator.validateConfig(config, failingExtractor);
        
        // Then
        assertThat(result.isValid()).isFalse();
        assertThat(result.getMessage()).contains("Failed to extract MTU");
    }
    
    @Test
    @DisplayName("Should build validator with custom settings")
    void shouldBuildValidatorWithCustomSettings() {
        // Given & When
        MtuValidator<String> customValidator = MtuValidator.<String>builder()
                .minMtu(1000)
                .maxMtu(2000)
                .protocol(MtuValidator.Protocol.IPV4)
                .customValidator(mtu -> mtu % 100 == 0)
                .validatorName("Custom Validator")
                .build();
        
        // Then
        assertThat(customValidator.getMinMtu()).isEqualTo(1000);
        assertThat(customValidator.getMaxMtu()).isEqualTo(2000);
        assertThat(customValidator.getProtocol()).isEqualTo(MtuValidator.Protocol.IPV4);
        assertThat(customValidator.getValidatorName()).isEqualTo("Custom Validator");
        
        // Test custom validation
        ValidationResult validResult = customValidator.validateMtuValue(1500);
        assertThat(validResult.isValid()).isTrue();
        
        ValidationResult invalidResult = customValidator.validateMtuValue(1550);
        assertThat(invalidResult.isValid()).isFalse();
    }
    
    @Test
    @DisplayName("Should provide validation result metadata")
    void shouldProvideValidationResultMetadata() {
        // When
        ValidationResult result = ethernetValidator.validateMtuValue(1500);
        
        // Then
        assertThat(result.getValidatorName()).isNotBlank();
        assertThat(result.getTimestamp()).isNotNull();
        assertThat(result.getRecommendations()).isNotNull();
        assertThat(result.toString()).contains("ValidationResult");
    }
    
    @Test
    @DisplayName("Should throw exception for invalid MTU range")
    void shouldThrowExceptionForInvalidMtuRange() {
        // When & Then
        assertThatThrownBy(() -> 
            MtuValidator.<String>builder()
                .minMtu(2000)
                .maxMtu(1000)
                .build()
        ).isInstanceOf(IllegalArgumentException.class)
         .hasMessageContaining("Invalid MTU range");
    }
}
