package com.network.mtu.cli;

import com.network.mtu.core.MtuExtractor;
import com.network.mtu.extractors.MtuExtractors;
import com.network.mtu.validator.MtuValidator;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.Callable;

/**
 * Command-line interface for the MTU Validator.
 * 
 * <p>This application provides a comprehensive CLI for validating MTU values
 * from various configuration sources including files, direct values, and
 * different configuration formats.
 * 
 * <p>Usage examples:
 * <pre>
 * # Validate a direct MTU value
 * java -jar mtu-validator.jar validate --value 1500
 * 
 * # Validate MTU from a JSON file
 * java -jar mtu-validator.jar validate --file config.json --format json --path "network.mtu"
 * 
 * # Validate with custom range
 * java -jar mtu-validator.jar validate --value 9000 --min 1500 --max 9000
 * </pre>
 * 
 * @since 1.0.0
 * @author MTU Validator Team
 */
@Command(
    name = "mtu-validator",
    description = "Validate Maximum Transmission Unit (MTU) values from various sources",
    version = "MTU Validator 1.0.0",
    mixinStandardHelpOptions = true,
    subcommands = {
        App.ValidateCommand.class,
        App.InfoCommand.class
    }
)
public class App implements Callable<Integer> {
    
    public static void main(String[] args) {
        int exitCode = new CommandLine(new App()).execute(args);
        System.exit(exitCode);
    }
    
    @Override
    public Integer call() {
        System.out.println("MTU Validator - Use --help for available commands");
        return 0;
    }
    
    /**
     * Command to validate MTU values from various sources.
     */
    @Command(
        name = "validate",
        description = "Validate MTU values from different sources and formats"
    )
    static class ValidateCommand implements Callable<Integer> {
        
        @Option(names = {"-v", "--value"}, description = "Direct MTU value to validate")
        private Integer mtuValue;
        
        @Option(names = {"-f", "--file"}, description = "Configuration file to read MTU from")
        private Path configFile;
        
        @Option(names = {"--format"}, description = "Configuration format: ${COMPLETION-CANDIDATES}")
        private ConfigFormat format = ConfigFormat.AUTO;
        
        @Option(names = {"-p", "--path"}, description = "Path to MTU value in configuration (for JSON/nested formats)")
        private String configPath = "mtu";
        
        @Option(names = {"--min"}, description = "Minimum allowed MTU value (default: 68)")
        private Integer minMtu = 68;
        
        @Option(names = {"--max"}, description = "Maximum allowed MTU value (default: 9000)")
        private Integer maxMtu = 9000;
        
        @Option(names = {"--protocol"}, description = "Network protocol: ${COMPLETION-CANDIDATES}")
        private MtuValidator.Protocol protocol = MtuValidator.Protocol.ETHERNET;
        
        @Option(names = {"--strict"}, description = "Enable strict validation mode")
        private boolean strictMode = false;
        
        @Option(names = {"-o", "--output"}, description = "Output format: ${COMPLETION-CANDIDATES}")
        private OutputFormat outputFormat = OutputFormat.HUMAN;
        
        @Option(names = {"--verbose"}, description = "Enable verbose output")
        private boolean verbose = false;
        
        @Override
        public Integer call() throws Exception {
            try {
                MtuValidator.ValidationResult result = performValidation();
                outputResult(result);
                return result.isValid() ? 0 : 1;
            } catch (Exception e) {
                System.err.println("Error: " + e.getMessage());
                if (verbose) {
                    e.printStackTrace();
                }
                return 2;
            }
        }
        
        private MtuValidator.ValidationResult performValidation() throws Exception {
            MtuValidator<Object> validator = MtuValidator.builder()
                    .minMtu(minMtu)
                    .maxMtu(maxMtu)
                    .protocol(protocol)
                    .strictMode(strictMode)
                    .validatorName("CLI Validator")
                    .build();
            
            if (mtuValue != null) {
                return validator.validateMtuValue(mtuValue);
            } else if (configFile != null) {
                return validateFromFile(validator);
            } else {
                throw new IllegalArgumentException("Either --value or --file must be specified");
            }
        }
        
        private MtuValidator.ValidationResult validateFromFile(MtuValidator<Object> validator) throws Exception {
            if (!Files.exists(configFile)) {
                throw new IOException("Configuration file not found: " + configFile);
            }
            
            String content = Files.readString(configFile);
            ConfigFormat actualFormat = format == ConfigFormat.AUTO ? detectFormat(configFile, content) : format;
            
            return switch (actualFormat) {
                case JSON -> {
                    MtuValidator<String> stringValidator = MtuValidator.forEthernet();
                    MtuExtractor<String> extractor = MtuExtractors.json()
                            .path(configPath)
                            .build();
                    yield stringValidator.validateConfig(content, extractor);
                }
                case PROPERTIES -> {
                    Properties props = new Properties();
                    props.load(Files.newBufferedReader(configFile));
                    MtuValidator<Properties> propsValidator = MtuValidator.forEthernet();
                    MtuExtractor<Properties> extractor = MtuExtractors.properties()
                            .key(configPath)
                            .build();
                    yield propsValidator.validateConfig(props, extractor);
                }
                case REGEX -> {
                    MtuValidator<String> stringValidator = MtuValidator.forEthernet();
                    MtuExtractor<String> extractor = MtuExtractors.regex()
                            .pattern("mtu[\\s=:]+([0-9]+)")
                            .groupIndex(1)
                            .build();
                    yield stringValidator.validateConfig(content, extractor);
                }
                default -> throw new IllegalArgumentException("Unsupported format: " + actualFormat);
            };
        }
        
        private ConfigFormat detectFormat(Path file, String content) {
            String fileName = file.getFileName().toString().toLowerCase();
            
            if (fileName.endsWith(".json")) {
                return ConfigFormat.JSON;
            } else if (fileName.endsWith(".properties")) {
                return ConfigFormat.PROPERTIES;
            } else if (content.trim().startsWith("{") || content.trim().startsWith("[")) {
                return ConfigFormat.JSON;
            } else if (content.contains("=") && content.lines().anyMatch(line -> line.contains("mtu"))) {
                return ConfigFormat.PROPERTIES;
            } else {
                return ConfigFormat.REGEX;
            }
        }
        
        private void outputResult(MtuValidator.ValidationResult result) {
            switch (outputFormat) {
                case JSON -> outputJson(result);
                case CSV -> outputCsv(result);
                case HUMAN -> outputHuman(result);
            }
        }
        
        private void outputHuman(MtuValidator.ValidationResult result) {
            System.out.println("=== MTU Validation Result ===");
            System.out.println("Status: " + (result.isValid() ? "✓ VALID" : "✗ INVALID"));
            System.out.println("MTU Value: " + result.getMtuValue());
            System.out.println("Message: " + result.getMessage());
            
            if (result.getNetworkType() != null) {
                System.out.println("Network Type: " + result.getNetworkType().getDisplayName());
            }
            
            if (!result.getRecommendations().isEmpty()) {
                System.out.println("\nRecommendations:");
                for (String recommendation : result.getRecommendations()) {
                    System.out.println("  • " + recommendation);
                }
            }
            
            if (verbose) {
                System.out.println("\nDetails:");
                System.out.println("  Validator: " + result.getValidatorName());
                System.out.println("  Timestamp: " + result.getTimestamp());
                if (result.getErrorCode() != null) {
                    System.out.println("  Error Code: " + result.getErrorCode());
                }
            }
        }
        
        private void outputJson(MtuValidator.ValidationResult result) {
            System.out.printf("""
                {
                  "valid": %s,
                  "mtuValue": %s,
                  "message": "%s",
                  "networkType": "%s",
                  "recommendations": [%s],
                  "validator": "%s",
                  "timestamp": "%s"
                }
                """,
                result.isValid(),
                result.getMtuValue() != null ? result.getMtuValue().toString() : "null",
                result.getMessage().replace("\"", "\\\""),
                result.getNetworkType() != null ? result.getNetworkType().getDisplayName() : "unknown",
                result.getRecommendations().stream()
                    .map(rec -> "\"" + rec.replace("\"", "\\\"") + "\"")
                    .reduce("", (a, b) -> a.isEmpty() ? b : a + ", " + b),
                result.getValidatorName(),
                result.getTimestamp()
            );
        }
        
        private void outputCsv(MtuValidator.ValidationResult result) {
            if (verbose) {
                System.out.println("valid,mtuValue,message,networkType,validator,timestamp");
            }
            System.out.printf("%s,%s,\"%s\",%s,%s,%s%n",
                result.isValid(),
                result.getMtuValue() != null ? result.getMtuValue().toString() : "",
                result.getMessage().replace("\"", "\"\""),
                result.getNetworkType() != null ? result.getNetworkType().getDisplayName() : "unknown",
                result.getValidatorName(),
                result.getTimestamp()
            );
        }
    }
    
    /**
     * Command to display information about the validator and supported formats.
     */
    @Command(
        name = "info",
        description = "Display information about MTU standards and supported formats"
    )
    static class InfoCommand implements Callable<Integer> {
        
        @Option(names = {"--standards"}, description = "Show MTU standards information")
        private boolean showStandards = false;
        
        @Option(names = {"--formats"}, description = "Show supported configuration formats")
        private boolean showFormats = false;
        
        @Override
        public Integer call() {
            if (!showStandards && !showFormats) {
                showStandards = showFormats = true;
            }
            
            if (showStandards) {
                displayStandards();
            }
            
            if (showFormats) {
                if (showStandards) System.out.println();
                displayFormats();
            }
            
            return 0;
        }
        
        private void displayStandards() {
            System.out.println("=== MTU Standards ===");
            System.out.println("IPv4 Minimum:     68 bytes (RFC 791)");
            System.out.println("IPv6 Minimum:     1280 bytes (RFC 8200)");
            System.out.println("Ethernet:         1500 bytes (IEEE 802.3)");
            System.out.println("PPPoE:            1492 bytes (1500 - 8 byte PPPoE header)");
            System.out.println("Jumbo Frames:     9000 bytes (common implementation)");
            System.out.println("Theoretical Max:  65535 bytes");
            
            System.out.println("\n=== Network Type Detection ===");
            System.out.println("1500 bytes → Ethernet");
            System.out.println("1492 bytes → PPPoE");
            System.out.println("9000 bytes → Jumbo Frame");
            System.out.println("< 1500     → Custom (Small)");
            System.out.println("> 1500     → Custom (Large)");
        }
        
        private void displayFormats() {
            System.out.println("=== Supported Configuration Formats ===");
            
            System.out.println("\n1. JSON Format:");
            System.out.println("   {\"network\": {\"mtu\": 1500}}");
            System.out.println("   Usage: --format json --path \"network.mtu\"");
            
            System.out.println("\n2. Properties Format:");
            System.out.println("   network.mtu=1500");
            System.out.println("   Usage: --format properties --path \"network.mtu\"");
            
            System.out.println("\n3. Text/Regex Format:");
            System.out.println("   interface eth0 mtu 1500");
            System.out.println("   Usage: --format regex (automatic pattern detection)");
            
            System.out.println("\n4. Direct Value:");
            System.out.println("   Usage: --value 1500");
        }
    }
    
    /**
     * Supported configuration formats.
     */
    enum ConfigFormat {
        AUTO, JSON, PROPERTIES, REGEX
    }
    
    /**
     * Output formats for validation results.
     */
    enum OutputFormat {
        HUMAN, JSON, CSV
    }
}
