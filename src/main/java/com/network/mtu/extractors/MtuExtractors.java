package com.network.mtu.extractors;

import java.util.Map;
import java.util.Properties;
import java.util.regex.Pattern;
import com.network.mtu.core.MtuExtractor;
import com.network.mtu.core.MtuExtractionException;
import com.network.mtu.core.ExtractorMetadata;

/**
 * Common implementations of MtuExtractor for various network configurations.
 */
public class MtuExtractors {
    
    /**
     * Creates a JSON-based MTU extractor.
     *
     * @return A builder for JSON extractor configuration
     */
    public static JsonExtractorBuilder json() {
        return new JsonExtractorBuilder();
    }
    
    /**
     * Creates a Properties-based MTU extractor.
     *
     * @return A builder for Properties extractor configuration
     */
    public static PropertiesExtractorBuilder properties() {
        return new PropertiesExtractorBuilder();
    }
    
    /**
     * Creates a regex-based MTU extractor.
     *
     * @return A builder for regex extractor configuration
     */
    public static RegexExtractorBuilder regex() {
        return new RegexExtractorBuilder();
    }
    
    /**
     * Creates a Map-based MTU extractor.
     *
     * @return A builder for Map extractor configuration
     */
    public static MapExtractorBuilder mapConfig() {
        return new MapExtractorBuilder();
    }
    
    /**
     * Extracts MTU from a Map-based configuration.
     */
    public static class MapConfigMtuExtractor implements MtuExtractor<Map<String, Object>> {
        private final String mtuKey;
        private final boolean caseInsensitive;
        private final Integer defaultValue;
        private final ExtractorMetadata metadata;
        
        /**
         * Constructs a new MapConfigMtuExtractor with the specified MTU key.
         *
         * @param mtuKey The key used to retrieve the MTU value from the map
         */
        public MapConfigMtuExtractor(String mtuKey) {
            this(mtuKey, false, null);
        }
        
        /**
         * Constructs a new MapConfigMtuExtractor with additional options.
         *
         * @param mtuKey The key used to retrieve the MTU value from the map
         * @param caseInsensitive Whether to use case-insensitive key matching
         * @param defaultValue Default value if key is not found
         */
        public MapConfigMtuExtractor(String mtuKey, boolean caseInsensitive, Integer defaultValue) {
            this.mtuKey = mtuKey;
            this.caseInsensitive = caseInsensitive;
            this.defaultValue = defaultValue;
            this.metadata = ExtractorMetadata.builder()
                .name("Map Config MTU Extractor")
                .description("Extracts MTU values from Map-based configurations")
                .author("MTU Validator Team")
                .property("mtuKey", mtuKey)
                .property("caseInsensitive", caseInsensitive)
                .property("defaultValue", defaultValue)
                .build();
        }
        
        @Override
        public int extractMtu(Map<String, Object> config) throws MtuExtractionException {
            if (config == null) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.CONFIG_NOT_FOUND, 
                    "Configuration map is null");
            }
            
            Object mtuValue = null;
            
            if (caseInsensitive) {
                // Case-insensitive search
                for (Map.Entry<String, Object> entry : config.entrySet()) {
                    if (entry.getKey().equalsIgnoreCase(mtuKey)) {
                        mtuValue = entry.getValue();
                        break;
                    }
                }
            } else {
                mtuValue = config.get(mtuKey);
            }
            
            if (mtuValue == null) {
                if (defaultValue != null) {
                    return defaultValue;
                }
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.MTU_NOT_FOUND, 
                    "MTU value not found for key: " + mtuKey);
            }
            
            try {
                return Integer.parseInt(mtuValue.toString());
            } catch (NumberFormatException e) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_MTU_FORMAT, 
                    "Invalid MTU value format: " + mtuValue, e);
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return metadata;
        }
    }
    
    /**
     * Extracts MTU from a JSON string configuration.
     */
    public static class JsonMtuExtractor implements MtuExtractor<String> {
        private final String jsonPath;
        private final ExtractorMetadata metadata;
        
        /**
         * Constructs a new JsonMtuExtractor with the specified JSON path.
         *
         * @param jsonPath The JSON path to the MTU value
         */
        public JsonMtuExtractor(String jsonPath) {
            this.jsonPath = jsonPath;
            this.metadata = ExtractorMetadata.builder()
                .name("JSON MTU Extractor")
                .description("Extracts MTU values from JSON configurations")
                .author("MTU Validator Team")
                .property("jsonPath", jsonPath)
                .build();
        }
        
        @Override
        public int extractMtu(String jsonConfig) throws MtuExtractionException {
            try {
                // Note: This is a simplified implementation. In practice, you would use
                // a proper JSON parsing library like Jackson or Gson
                if (jsonConfig == null || jsonConfig.isEmpty()) {
                    throw new MtuExtractionException(MtuExtractionException.ErrorCode.CONFIG_NOT_FOUND, 
                        "Empty JSON configuration");
                }
                // Implementation would parse JSON and extract MTU value
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_FORMAT, 
                    "JSON parsing not implemented - use a proper JSON library");
            } catch (Exception e) {
                if (e instanceof MtuExtractionException) {
                    throw (MtuExtractionException) e;
                }
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_FORMAT, 
                    "Failed to extract MTU from JSON", e);
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return metadata;
        }
    }
    
    /**
     * Extracts MTU from Properties configuration.
     */
    public static class PropertiesMtuExtractor implements MtuExtractor<Properties> {
        private final String key;
        private final String defaultValue;
        private final ExtractorMetadata metadata;
        
        /**
         * Constructs a new PropertiesMtuExtractor.
         *
         * @param key The property key for MTU value
         * @param defaultValue Default value if key is not found
         */
        public PropertiesMtuExtractor(String key, String defaultValue) {
            this.key = key;
            this.defaultValue = defaultValue;
            this.metadata = ExtractorMetadata.builder()
                .name("Properties MTU Extractor")
                .description("Extracts MTU values from Properties configurations")
                .author("MTU Validator Team")
                .property("key", key)
                .property("defaultValue", defaultValue)
                .build();
        }
        
        @Override
        public int extractMtu(Properties config) throws MtuExtractionException {
            if (config == null) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.CONFIG_NOT_FOUND, 
                    "Properties configuration is null");
            }
            
            String value = config.getProperty(key, defaultValue);
            if (value == null) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.MTU_NOT_FOUND, 
                    "MTU value not found for key: " + key);
            }
            
            try {
                return Integer.parseInt(value.trim());
            } catch (NumberFormatException e) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_MTU_FORMAT, 
                    "Invalid MTU value format: " + value, e);
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return metadata;
        }
    }
    
    /**
     * Extracts MTU from text using regex patterns.
     */
    public static class RegexMtuExtractor implements MtuExtractor<String> {
        private final Pattern pattern;
        private final int groupIndex;
        private final boolean multiline;
        private final ExtractorMetadata metadata;
        
        /**
         * Constructs a new RegexMtuExtractor.
         *
         * @param pattern The regex pattern to match MTU values
         * @param groupIndex The capture group index containing the MTU value
         * @param multiline Whether to use multiline mode
         */
        public RegexMtuExtractor(String pattern, int groupIndex, boolean multiline) {
            this.pattern = Pattern.compile(pattern, multiline ? Pattern.MULTILINE : 0);
            this.groupIndex = groupIndex;
            this.multiline = multiline;
            this.metadata = ExtractorMetadata.builder()
                .name("Regex MTU Extractor")
                .description("Extracts MTU values using regex patterns")
                .author("MTU Validator Team")
                .property("pattern", pattern)
                .property("groupIndex", groupIndex)
                .property("multiline", multiline)
                .build();
        }
        
        @Override
        public int extractMtu(String text) throws MtuExtractionException {
            if (text == null || text.isEmpty()) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.CONFIG_NOT_FOUND, 
                    "Text is null or empty");
            }
            
            var matcher = pattern.matcher(text);
            if (matcher.find()) {
                try {
                    String group = matcher.group(groupIndex);
                    return Integer.parseInt(group);
                } catch (IndexOutOfBoundsException e) {
                    throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_FORMAT, 
                        "Invalid group index: " + groupIndex, e);
                } catch (NumberFormatException e) {
                    throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_MTU_FORMAT, 
                        "Invalid MTU value in matched group", e);
                }
            } else {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.MTU_NOT_FOUND, 
                    "No MTU value found matching pattern: " + pattern.pattern());
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return metadata;
        }
    }
    
    /**
     * Extracts MTU from macOS network service configuration using system commands.
     */
    public static class MacOsNetworkServiceMtuExtractor implements MtuExtractor<String> {
        private final ExtractorMetadata metadata;
        
        public MacOsNetworkServiceMtuExtractor() {
            this.metadata = ExtractorMetadata.builder()
                .name("macOS Network Service MTU Extractor")
                .description("Extracts MTU values from macOS network services using system commands")
                .author("MTU Validator Team")
                .property("platform", "macOS")
                .property("command", "networksetup")
                .build();
        }
        
        @Override
        public int extractMtu(String serviceName) throws MtuExtractionException {
            if (serviceName == null || serviceName.trim().isEmpty()) {
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.CONFIG_NOT_FOUND, 
                    "Network service name cannot be empty");
            }
            
            try {
                ProcessBuilder pb = new ProcessBuilder(
                    "networksetup", "-getmtu", serviceName.trim());
                Process p = pb.start();
                
                try (java.io.BufferedReader br = new java.io.BufferedReader(
                         new java.io.InputStreamReader(p.getInputStream()))) {
                    String line = br.readLine();
                    if (line == null) {
                        throw new MtuExtractionException(MtuExtractionException.ErrorCode.PLATFORM_ERROR, 
                            "No output from networksetup command");
                    }
                    
                    // Expected format: "Active MTU: 1500 (Current Setting: 1500)"
                    java.util.regex.Pattern pattern = 
                        java.util.regex.Pattern.compile("Active MTU: (\\d+)");
                    java.util.regex.Matcher matcher = pattern.matcher(line);
                    
                    if (matcher.find()) {
                        return Integer.parseInt(matcher.group(1));
                    } else {
                        throw new MtuExtractionException(MtuExtractionException.ErrorCode.INVALID_FORMAT, 
                            "Unexpected output format: " + line);
                    }
                }
            } catch (Exception e) {
                if (e instanceof MtuExtractionException) {
                    throw (MtuExtractionException) e;
                }
                throw new MtuExtractionException(MtuExtractionException.ErrorCode.PLATFORM_ERROR, 
                    "Failed to extract MTU for service: " + serviceName, e);
            }
        }
        
        @Override
        public ExtractorMetadata getMetadata() {
            return metadata;
        }
    }
    
    // Builder classes for fluent API
    
    public static class JsonExtractorBuilder {
        private String path = "mtu";
        
        public JsonExtractorBuilder path(String path) {
            this.path = path;
            return this;
        }
        
        public JsonMtuExtractor build() {
            return new JsonMtuExtractor(path);
        }
    }
    
    public static class PropertiesExtractorBuilder {
        private String key = "mtu";
        private String defaultValue = null;
        
        public PropertiesExtractorBuilder key(String key) {
            this.key = key;
            return this;
        }
        
        public PropertiesExtractorBuilder defaultValue(String defaultValue) {
            this.defaultValue = defaultValue;
            return this;
        }
        
        public PropertiesMtuExtractor build() {
            return new PropertiesMtuExtractor(key, defaultValue);
        }
    }
    
    public static class RegexExtractorBuilder {
        private String pattern = "mtu\\s+(\\d+)";
        private int groupIndex = 1;
        private boolean multiline = false;
        
        public RegexExtractorBuilder pattern(String pattern) {
            this.pattern = pattern;
            return this;
        }
        
        public RegexExtractorBuilder groupIndex(int groupIndex) {
            this.groupIndex = groupIndex;
            return this;
        }
        
        public RegexExtractorBuilder multiline(boolean multiline) {
            this.multiline = multiline;
            return this;
        }
        
        public RegexMtuExtractor build() {
            return new RegexMtuExtractor(pattern, groupIndex, multiline);
        }
    }
    
    public static class MapExtractorBuilder {
        private String key = "mtu";
        private boolean caseInsensitive = false;
        private Integer defaultValue = null;
        
        public MapExtractorBuilder key(String key) {
            this.key = key;
            return this;
        }
        
        public MapExtractorBuilder caseInsensitive(boolean caseInsensitive) {
            this.caseInsensitive = caseInsensitive;
            return this;
        }
        
        public MapExtractorBuilder defaultValue(Integer defaultValue) {
            this.defaultValue = defaultValue;
            return this;
        }
        
        public MapConfigMtuExtractor build() {
            return new MapConfigMtuExtractor(key, caseInsensitive, defaultValue);
        }
    }
}