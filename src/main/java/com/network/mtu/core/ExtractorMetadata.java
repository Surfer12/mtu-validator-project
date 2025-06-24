package com.network.mtu.core;

import java.time.Instant;
import java.util.Map;
import java.util.HashMap;

/**
 * Metadata about an MTU extractor implementation.
 */
public class ExtractorMetadata {
    private final String name;
    private final String version;
    private final String description;
    private final String author;
    private final Instant created;
    private final Map<String, Object> properties;
    
    private ExtractorMetadata(Builder builder) {
        this.name = builder.name;
        this.version = builder.version;
        this.description = builder.description;
        this.author = builder.author;
        this.created = builder.created != null ? builder.created : Instant.now();
        this.properties = new HashMap<>(builder.properties);
    }
    
    /**
     * Gets the name of the extractor.
     *
     * @return The extractor name
     */
    public String getName() {
        return name;
    }
    
    /**
     * Gets the version of the extractor.
     *
     * @return The extractor version
     */
    public String getVersion() {
        return version;
    }
    
    /**
     * Gets the description of the extractor.
     *
     * @return The extractor description
     */
    public String getDescription() {
        return description;
    }
    
    /**
     * Gets the author of the extractor.
     *
     * @return The extractor author
     */
    public String getAuthor() {
        return author;
    }
    
    /**
     * Gets the creation timestamp of the extractor.
     *
     * @return The creation timestamp
     */
    public Instant getCreated() {
        return created;
    }
    
    /**
     * Gets a property value.
     *
     * @param key The property key
     * @return The property value, or null if not found
     */
    public Object getProperty(String key) {
        return properties.get(key);
    }
    
    /**
     * Gets all properties as an immutable map.
     *
     * @return The properties map
     */
    public Map<String, Object> getProperties() {
        return Map.copyOf(properties);
    }
    
    /**
     * Builder for ExtractorMetadata.
     */
    public static class Builder {
        private String name;
        private String version = "1.0.0";
        private String description;
        private String author;
        private Instant created;
        private final Map<String, Object> properties = new HashMap<>();
        
        /**
         * Sets the extractor name.
         *
         * @param name The extractor name
         * @return This builder
         */
        public Builder name(String name) {
            this.name = name;
            return this;
        }
        
        /**
         * Sets the extractor version.
         *
         * @param version The extractor version
         * @return This builder
         */
        public Builder version(String version) {
            this.version = version;
            return this;
        }
        
        /**
         * Sets the extractor description.
         *
         * @param description The extractor description
         * @return This builder
         */
        public Builder description(String description) {
            this.description = description;
            return this;
        }
        
        /**
         * Sets the extractor author.
         *
         * @param author The extractor author
         * @return This builder
         */
        public Builder author(String author) {
            this.author = author;
            return this;
        }
        
        /**
         * Sets the creation timestamp.
         *
         * @param created The creation timestamp
         * @return This builder
         */
        public Builder created(Instant created) {
            this.created = created;
            return this;
        }
        
        /**
         * Adds a property.
         *
         * @param key The property key
         * @param value The property value
         * @return This builder
         */
        public Builder property(String key, Object value) {
            this.properties.put(key, value);
            return this;
        }
        
        /**
         * Builds the ExtractorMetadata.
         *
         * @return The built ExtractorMetadata
         * @throws IllegalArgumentException if required fields are missing
         */
        public ExtractorMetadata build() {
            if (name == null || name.trim().isEmpty()) {
                throw new IllegalArgumentException("Name is required");
            }
            if (description == null || description.trim().isEmpty()) {
                throw new IllegalArgumentException("Description is required");
            }
            return new ExtractorMetadata(this);
        }
    }
    
    /**
     * Creates a new builder for ExtractorMetadata.
     *
     * @return A new builder
     */
    public static Builder builder() {
        return new Builder();
    }
} 