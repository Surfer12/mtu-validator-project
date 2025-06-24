import java.util.Map;

/**
 * Common implementations of MtuExtractor for various network configurations.
 */
public class MtuExtractors {
    
    /**
     * Extracts MTU from a Map-based configuration.
     */
    public static class MapConfigMtuExtractor implements MtuExtractor<Map<String, Object>> {
        private final String mtuKey;
        
        /**
         * Constructs a new MapConfigMtuExtractor with the specified MTU key.
         *
         * @param mtuKey The key used to retrieve the MTU value from the map
         */
        public MapConfigMtuExtractor(String mtuKey) {
            this.mtuKey = mtuKey;
        }
        
        @Override
        public int extractMtu(Map<String, Object> config) throws MtuExtractionException {
            Object mtuValue = config.get(mtuKey);
            if (mtuValue == null) {
                throw new MtuExtractionException("MTU value not found for key: " + mtuKey);
            }
            try {
                return Integer.parseInt(mtuValue.toString());
            } catch (NumberFormatException e) {
                throw new MtuExtractionException("Invalid MTU value format", e);
            }
        }
    }
    
    /**
     * Extracts MTU from a JSON string configuration.
     */
    public static class JsonMtuExtractor implements MtuExtractor<String> {
        private final String jsonPath;
        
        /**
         * Constructs a new JsonMtuExtractor with the specified JSON path.
         *
         * @param jsonPath The JSON path to the MTU value
         */
        public JsonMtuExtractor(String jsonPath) {
            this.jsonPath = jsonPath;
        }
        
        @Override
        public int extractMtu(String jsonConfig) throws MtuExtractionException {
            try {
                // Note: This is a simplified implementation. In practice, you would use
                // a proper JSON parsing library like Jackson or Gson
                if (jsonConfig == null || jsonConfig.isEmpty()) {
                    throw new MtuExtractionException("Empty JSON configuration");
                }
                // Implementation would parse JSON and extract MTU value
                throw new MtuExtractionException("JSON parsing not implemented - use a proper JSON library");
            } catch (Exception e) {
                throw new MtuExtractionException("Failed to extract MTU from JSON", e);
            }
        }
    }
    
    /**
     * Extracts MTU from macOS network service configuration using system commands.
     */
    public static class MacOsNetworkServiceMtuExtractor implements MtuExtractor<String> {
        
        @Override
        public int extractMtu(String serviceName) throws MtuExtractionException {
            if (serviceName == null || serviceName.trim().isEmpty()) {
                throw new MtuExtractionException("Network service name cannot be empty");
            }
            
            try {
                ProcessBuilder pb = new ProcessBuilder(
                    "networksetup", "-getmtu", serviceName.trim());
                Process p = pb.start();
                
                try (java.io.BufferedReader br = new java.io.BufferedReader(
                         new java.io.InputStreamReader(p.getInputStream()))) {
                    String line = br.readLine();
                    if (line == null) {
                        throw new MtuExtractionException("No output from networksetup command");
                    }
                    
                    // Expected format: "Active MTU: 1500 (Current Setting: 1500)"
                    java.util.regex.Pattern pattern = 
                        java.util.regex.Pattern.compile("Active MTU: (\\d+)");
                    java.util.regex.Matcher matcher = pattern.matcher(line);
                    
                    if (matcher.find()) {
                        return Integer.parseInt(matcher.group(1));
                    } else {
                        throw new MtuExtractionException("Unexpected output format: " + line);
                    }
                }
            } catch (Exception e) {
                if (e instanceof MtuExtractionException) {
                    throw (MtuExtractionException) e;
                }
                throw new MtuExtractionException("Failed to extract MTU for service: " + serviceName, e);
            }
        }
    }
}