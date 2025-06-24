/**
 * Exception thrown when MTU extraction fails.
 */
public class MtuExtractionException extends Exception {
    
    /**
     * Constructs a new MtuExtractionException with the specified detail message.
     *
     * @param message The detail message
     */
    public MtuExtractionException(String message) {
        super(message);
    }
    
    /**
     * Constructs a new MtuExtractionException with the specified detail message and cause.
     *
     * @param message The detail message
     * @param cause The cause of the exception
     */
    public MtuExtractionException(String message, Throwable cause) {
        super(message, cause);
    }
}