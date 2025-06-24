import java.util.HashMap;
import java.util.Map;

/**
 * Example usage of the MTU validation framework.
 */
public class MtuValidatorExample {

    public static void main(String[] args) {
        try {
            // Example with standard Ethernet MTU range
            MtuValidator<String> ethernetValidator = new MtuValidator<>(576, MtuValidator.ETHERNET_MTU);
            
            // Example with jumbo frame MTU range
            MtuValidator<Map<String, Object>> jumboValidator = new MtuValidator<>(1500, MtuValidator.JUMBO_FRAME_MTU);
            
            // Validate macOS Wi-Fi interface MTU
            MtuExtractor<String> macOsExtractor = new MtuExtractors.MacOsNetworkServiceMtuExtractor();
            MtuValidator.ValidationResult wifiResult = ethernetValidator.validateConfig("Wi-Fi", macOsExtractor);
            System.out.println("Wi-Fi MTU validation: " + wifiResult.getMessage());
            
            // Validate a configuration from a Map
            Map<String, Object> networkConfig = new HashMap<>();
            networkConfig.put("mtu", 1500);
            networkConfig.put("interface", "eth0");
            
            MtuExtractor<Map<String, Object>> mapExtractor = new MtuExtractors.MapConfigMtuExtractor("mtu");
            MtuValidator.ValidationResult mapResult = jumboValidator.validateConfig(networkConfig, mapExtractor);
            System.out.println("Map config validation: " + mapResult.getMessage());
            
            // Example with lambda for a custom network configuration
            class CustomNetworkConfig {
                private final int mtuSize;
                
                public CustomNetworkConfig(int mtuSize) {
                    this.mtuSize = mtuSize;
                }
                
                public int getMtuSize() {
                    return mtuSize;
                }
            }
            
            CustomNetworkConfig customConfig = new CustomNetworkConfig(9000);
            MtuValidator<CustomNetworkConfig> customValidator = 
                new MtuValidator<>(1500, MtuValidator.JUMBO_FRAME_MTU);
                
            MtuExtractor<CustomNetworkConfig> lambdaExtractor = 
                config -> config.getMtuSize();
                
            MtuValidator.ValidationResult customResult = 
                customValidator.validateConfig(customConfig, lambdaExtractor);
                
            System.out.println("Custom config validation: " + customResult.getMessage());
            
        } catch (Exception e) {
            System.err.println("Error during MTU validation: " + e.getMessage());
            e.printStackTrace();
        }
    }
}