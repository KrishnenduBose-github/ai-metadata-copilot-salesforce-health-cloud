public with sharing class MetadataLogger {
    private static final String LOG_DEBUG = 'DEBUG';
    private static final String LOG_INFO = 'INFO';
    private static final String LOG_WARN = 'WARN';
    private static final String LOG_ERROR = 'ERROR';

    public static void debug(String source, String message) {
        logInternal(LOG_DEBUG, source, message, null);
    }

    public static void info(String source, String message) {
        logInternal(LOG_INFO, source, message, null);
    }

    public static void warn(String source, String message) {
        logInternal(LOG_WARN, source, message, null);
    }

    public static void error(String source, String message) {
        logInternal(LOG_ERROR, source, message, null);
    }

    public static void error(String source, String message, Exception ex) {
        logInternal(LOG_ERROR, source, message, ex);
    }

    private static void logInternal(String logLevel, String source, String message, Exception ex) {
        String logEntry = logLevel + ' [' + safeText(source) + '] ' + safeText(message);

        if (ex != null) {
            logEntry += ' | ' + ex.getTypeName() + ': ' + ex.getMessage();
        }

        if (logLevel == LOG_ERROR) {
            System.debug(LoggingLevel.ERROR, logEntry);
        } else if (logLevel == LOG_WARN) {
            System.debug(LoggingLevel.WARN, logEntry);
        } else if (logLevel == LOG_INFO) {
            System.debug(LoggingLevel.INFO, logEntry);
        } else {
            System.debug(LoggingLevel.DEBUG, logEntry);
        }
    }

    private static String safeText(String inputText) {
        return String.isBlank(inputText) ? '(none)' : inputText;
    }
}
