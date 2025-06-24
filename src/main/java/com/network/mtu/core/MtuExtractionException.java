package com.network.mtu.core;

import java.time.Instant;

/**
 * Exception thrown when MTU extraction fails.
 */
public class MtuExtractionException extends Exception {
    
    /**
     * Error codes for different types of extraction failures.
     */
    public enum ErrorCode {
        CONFIG_NOT_FOUND("Configuration not found"),
        MTU_NOT_FOUND("MTU value not found in configuration"),
        INVALID_FORMAT("Invalid configuration format"),
        INVALID_MTU_FORMAT("Invalid MTU value format"),
        PLATFORM_ERROR("Platform-specific error"),
        TIMEOUT("Operation timeout");
        
        private final String description;
        
        ErrorCode(String description) {
            this.description = description;
        }
        
        public String getDescription() {
            return description;
        }
    }
    
    private final ErrorCode errorCode;
    private final Instant timestamp;
    
    /**
     * Constructs a new MtuExtractionException with the specified detail message.
     *
     * @param message The detail message
     */
    public MtuExtractionException(String message) {
        super(message);
        this.errorCode = ErrorCode.INVALID_FORMAT;
        this.timestamp = Instant.now();
    }
    
    /**
     * Constructs a new MtuExtractionException with the specified detail message and cause.
     *
     * @param message The detail message
     * @param cause The cause of the exception
     */
    public MtuExtractionException(String message, Throwable cause) {
        super(message, cause);
        this.errorCode = ErrorCode.INVALID_FORMAT;
        this.timestamp = Instant.now();
    }
    
    /**
     * Constructs a new MtuExtractionException with the specified error code and message.
     *
     * @param errorCode The specific error code
     * @param message The detail message
     */
    public MtuExtractionException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
        this.timestamp = Instant.now();
    }
    
    /**
     * Constructs a new MtuExtractionException with the specified error code, message, and cause.
     *
     * @param errorCode The specific error code
     * @param message The detail message
     * @param cause The cause of the exception
     */
    public MtuExtractionException(ErrorCode errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.timestamp = Instant.now();
    }
    
    /**
     * Gets the error code for this exception.
     *
     * @return The error code
     */
    public ErrorCode getErrorCode() {
        return errorCode;
    }
    
    /**
     * Gets the timestamp when this exception was created.
     *
     * @return The timestamp
     */
    public Instant getTimestamp() {
        return timestamp;
    }
}