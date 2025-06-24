package com.network.mtu.platform.macos;

import com.network.mtu.core.MtuExtractor;
import com.network.mtu.core.MtuExtractionException;
import com.network.mtu.core.MtuExtractionException.ErrorCode;
import com.network.mtu.validator.MtuValidator;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * macOS-specific network preference validator for MTU values.
 * 
 * <p>This class provides platform-specific functionality for extracting and validating
 * MTU values from macOS network configurations using system commands like
 * {@code networksetup} and {@code ifconfig}.
 * 
 * <p>Features:
 * <ul>
 *   <li>Extract MTU from specific network services (Wi-Fi, Ethernet, etc.)</li>
 *   <li>Validate network service order</li>
 *   <li>Check DNS and other network properties</li>
 *   <li>Asynchronous operations with timeout support</li>
 *   <li>Comprehensive error handling with specific error codes</li>
 * </ul>
 * 
 * <p>Example usage:
 * <pre>{@code
 * // Extract MTU from Wi-Fi interface
 * MacNetworkServiceMtuExtractor extractor = MacNetworkServiceMtuExtractor.builder()
 *     .serviceName("Wi-Fi")
 *     .timeout(5, TimeUnit.SECONDS)
 *     .build();
 * 
 * int mtu = extractor.extractMtu("Wi-Fi");
 * }</pre>
 * 
 * <p><strong>Platform Requirements:</strong>
 * <ul>
 *   <li>macOS 10.12 or later</li>
 *   <li>Access to {@code networksetup} and {@code ifconfig} commands</li>
 *   <li>Appropriate permissions for network operations</li>
 * </ul>
 * 
 * @since 1.0.0
 * @author MTU Validator Team
 */
public class MacNetworkPreferenceValidator<T> {
    
    private final NetworkPreferenceExtractor<T> extractor;
    private final MtuValidator<T> validator;
    private final long timeoutSeconds;
    
    private MacNetworkPreferenceValidator(Builder<T> builder) {
        this.extractor = Objects.requireNonNull(builder.extractor, "Extractor cannot be null");
        this.validator = Objects.requireNonNull(builder.validator, "Validator cannot be null");
        this.timeoutSeconds = builder.timeoutSeconds;
    }
    
    /**
     * Creates a new builder for MacNetworkPreferenceValidator.
     *
     * @param <T> The type of configuration to validate
     * @return A new builder instance
     */
    public static <T> Builder<T> builder() {
        return new Builder<>();
    }
    
    /**
     * Creates a validator for network service order.
     *
     * @param expectedOrder The expected order of network services
     * @return A configured validator for service order
     */
    public static MacNetworkPreferenceValidator<List<String>> forServiceOrder(List<String> expectedOrder) {
        return MacNetworkPreferenceValidator.<List<String>>builder()
                .extractor(new ServiceOrderExtractor())
                .validator(MtuValidator.<List<String>>builder()
                        .customValidator(order -> order.equals(expectedOrder))
                        .validatorName("Service Order Validator")
                        .build())
                .build();
    }
    
    /**
     * Creates a validator for a specific service property.
     *
     * @param serviceName The name of the network service
     * @param property The property to validate
     * @param expectedValue The expected value
     * @return A configured validator for the service property
     */
    public static MacNetworkPreferenceValidator<String> forServiceProperty(
            String serviceName, String property, String expectedValue) {
        return MacNetworkPreferenceValidator.<String>builder()
                .extractor(new ServicePropertyExtractor(serviceName, property))
                .validator(MtuValidator.<String>builder()
                        .customValidator(value -> expectedValue.equals(value))
                        .validatorName("Service Property Validator")
                        .build())
                .build();
    }
    
    /**
     * Validates the network configuration.
     *
     * @return ValidationResult containing the validation outcome
     */
    public MtuValidator.ValidationResult validate() {
        try {
            T config = extractor.extract();
            return validator.validateConfig(config, createDummyExtractor());
        } catch (Exception e) {
            return MtuValidator.ValidationResult.builder()
                    .valid(false)
                    .message("Validation failed: " + e.getMessage())
                    .validatorName("Mac Network Validator")
                    .build();
        }
    }
    
    /**
     * Asynchronously validates the network configuration.
     *
     * @return CompletableFuture containing the validation result
     */
    public CompletableFuture<MtuValidator.ValidationResult> validateAsync() {
        return CompletableFuture.supplyAsync(this::validate)
                .orTimeout(timeoutSeconds, TimeUnit.SECONDS);
    }
    
    private MtuExtractor<T> createDummyExtractor() {
        return config -> 1500; // Dummy implementation for compatibility
    }
    
    /**
     * Interface for extracting network preferences from macOS.
     */
    @FunctionalInterface
    public interface NetworkPreferenceExtractor<T> {
        T extract() throws Exception;
    }
    
    /**
     * Builder class for MacNetworkPreferenceValidator.
     */
    public static class Builder<T> {
        private NetworkPreferenceExtractor<T> extractor;
        private MtuValidator<T> validator;
        private long timeoutSeconds = 10;
        
        public Builder<T> extractor(NetworkPreferenceExtractor<T> extractor) {
            this.extractor = extractor;
            return this;
        }
        
        public Builder<T> validator(MtuValidator<T> validator) {
            this.validator = validator;
            return this;
        }
        
        public Builder<T> timeout(long timeout, TimeUnit unit) {
            this.timeoutSeconds = unit.toSeconds(timeout);
            return this;
        }
        
        public MacNetworkPreferenceValidator<T> build() {
            return new MacNetworkPreferenceValidator<>(this);
        }
    }
    
    /**
     * Extractor for network service order.
     */
    private static class ServiceOrderExtractor implements NetworkPreferenceExtractor<List<String>> {
        @Override
        public List<String> extract() throws Exception {
            ProcessBuilder pb = new ProcessBuilder("networksetup", "-listnetworkserviceorder");
            Process process = pb.start();
            
            List<String> services = new ArrayList<>();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.startsWith("(") && line.contains(")")) {
                        String serviceName = line.substring(line.indexOf(')') + 2).trim();
                        services.add(serviceName);
                    }
                }
            }
            
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new RuntimeException("networksetup command failed with exit code: " + exitCode);
            }
            
            return services;
        }
    }
    
    /**
     * Extractor for specific service properties.
     */
    private static class ServicePropertyExtractor implements NetworkPreferenceExtractor<String> {
        private final String serviceName;
        private final String property;
        
        public ServicePropertyExtractor(String serviceName, String property) {
            this.serviceName = serviceName;
            this.property = property;
        }
        
        @Override
        public String extract() throws Exception {
            ProcessBuilder pb = switch (property.toLowerCase()) {
                case "dns" -> new ProcessBuilder("networksetup", "-getdnsservers", serviceName);
                case "mtu" -> new ProcessBuilder("networksetup", "-getMTU", serviceName);
                default -> throw new IllegalArgumentException("Unsupported property: " + property);
            };
            
            Process process = pb.start();
            StringBuilder output = new StringBuilder();
            
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
            }
            
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new RuntimeException("networksetup command failed with exit code: " + exitCode);
            }
            
            return output.toString().trim();
        }
    }
    
    /**
     * MTU extractor specifically for macOS network services.
     */
    public static class MacNetworkServiceMtuExtractor implements MtuExtractor<String> {
        private final String serviceName;
        private final boolean useIfconfig;
        private final long timeoutSeconds;
        private final Pattern mtuPattern;
        
        private MacNetworkServiceMtuExtractor(Builder builder) {
            this.serviceName = Objects.requireNonNull(builder.serviceName, "Service name cannot be null");
            this.useIfconfig = builder.useIfconfig;
            this.timeoutSeconds = builder.timeoutSeconds;
            this.mtuPattern = Pattern.compile("mtu\\s+(\\d+)", Pattern.CASE_INSENSITIVE);
        }
        
        public static Builder builder() {
            return new Builder();
        }
        
        @Override
        public int extractMtu(String serviceName) throws MtuExtractionException {
            try {
                if (useIfconfig) {
                    return extractMtuFromIfconfig(serviceName);
                } else {
                    return extractMtuFromNetworksetup(serviceName);
                }
            } catch (Exception e) {
                throw new MtuExtractionException(ErrorCode.PLATFORM_ERROR, 
                        "Failed to extract MTU from macOS service: " + serviceName, e);
            }
        }
        
        private int extractMtuFromNetworksetup(String serviceName) throws Exception {
            ProcessBuilder pb = new ProcessBuilder("networksetup", "-getMTU", serviceName);
            Process process = pb.start();
            
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append(" ");
                }
            }
            
            boolean finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                throw new MtuExtractionException(ErrorCode.TIMEOUT, 
                        "Timeout waiting for networksetup command");
            }
            
            int exitCode = process.exitValue();
            if (exitCode != 0) {
                throw new MtuExtractionException(ErrorCode.PLATFORM_ERROR, 
                        "networksetup command failed with exit code: " + exitCode);
            }
            
            String result = output.toString().trim();
            Matcher matcher = mtuPattern.matcher(result);
            
            if (matcher.find()) {
                return Integer.parseInt(matcher.group(1));
            } else {
                throw new MtuExtractionException(ErrorCode.MTU_NOT_FOUND, 
                        "MTU value not found in networksetup output: " + result);
            }
        }
        
        private int extractMtuFromIfconfig(String interfaceName) throws Exception {
            ProcessBuilder pb = new ProcessBuilder("ifconfig", interfaceName);
            Process process = pb.start();
            
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append(" ");
                }
            }
            
            boolean finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                throw new MtuExtractionException(ErrorCode.TIMEOUT, 
                        "Timeout waiting for ifconfig command");
            }
            
            int exitCode = process.exitValue();
            if (exitCode != 0) {
                throw new MtuExtractionException(ErrorCode.INTERFACE_NOT_FOUND, 
                        "Interface not found or ifconfig failed: " + interfaceName);
            }
            
            String result = output.toString();
            Matcher matcher = mtuPattern.matcher(result);
            
            if (matcher.find()) {
                return Integer.parseInt(matcher.group(1));
            } else {
                throw new MtuExtractionException(ErrorCode.MTU_NOT_FOUND, 
                        "MTU value not found in ifconfig output for interface: " + interfaceName);
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return ExtractorMetadata.builder()
                    .name("MacNetworkServiceMtuExtractor")
                    .description("Extracts MTU from macOS network services using networksetup or ifconfig")
                    .version("1.0.0")
                    .supportedConfigTypes(String.class)
                    .supportsAsync(true)
                    .requiresPrivileges(false)
                    .supportedPlatforms("macOS")
                    .build();
        }
        
        /**
         * Builder for MacNetworkServiceMtuExtractor.
         */
        public static class Builder {
            private String serviceName;
            private boolean useIfconfig = false;
            private long timeoutSeconds = 10;
            
            public Builder serviceName(String serviceName) {
                this.serviceName = serviceName;
                return this;
            }
            
            public Builder useIfconfig(boolean useIfconfig) {
                this.useIfconfig = useIfconfig;
                return this;
            }
            
            public Builder timeout(long timeout, TimeUnit unit) {
                this.timeoutSeconds = unit.toSeconds(timeout);
                return this;
            }
            
            public MacNetworkServiceMtuExtractor build() {
                return new MacNetworkServiceMtuExtractor(this);
            }
        }
    }
    
    /**
     * Validation result specific to macOS network preferences.
     */
    public static class ValidationResult extends MtuValidator.ValidationResult {
        private final String platformInfo;
        private final List<String> availableServices;
        
        private ValidationResult(Builder builder) {
            super(MtuValidator.ValidationResult.builder()
                    .valid(builder.valid)
                    .message(builder.message)
                    .build());
            this.platformInfo = builder.platformInfo;
            this.availableServices = builder.availableServices != null ? 
                    new ArrayList<>(builder.availableServices) : new ArrayList<>();
        }
        
        public static Builder builder() {
            return new Builder();
        }
        
        public String getPlatformInfo() {
            return platformInfo;
        }
        
        public List<String> getAvailableServices() {
            return new ArrayList<>(availableServices);
        }
        
        /**
         * Builder for macOS-specific ValidationResult.
         */
        public static class Builder {
            private boolean valid;
            private String message;
            private String platformInfo;
            private List<String> availableServices;
            
            public Builder valid(boolean valid) {
                this.valid = valid;
                return this;
            }
            
            public Builder message(String message) {
                this.message = message;
                return this;
            }
            
            public Builder platformInfo(String platformInfo) {
                this.platformInfo = platformInfo;
                return this;
            }
            
            public Builder availableServices(List<String> services) {
                this.availableServices = services;
                return this;
            }
            
            public ValidationResult build() {
                return new ValidationResult(this);
            }
        }
    }
}
