/* eslint-disable */
import React, { useState, useEffect } from "react";
import {
  Send,
  MessageCircle,
  Database,
  Cloud,
  Activity,
  CheckCircle,
  XCircle,
  Clock,
  Zap,
} from "lucide-react";

const MessagePublisher = () => {
  const [message, setMessage] = useState("");
  const [metadata, setMetadata] = useState("");
  const [selectedPublisher, setSelectedPublisher] = useState("kafka-sns");
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState([]);
  const [apiStatus, setApiStatus] = useState(null);

  const publisherOptions = [
    {
      value: "kafka-sns",
      label: "Kafka + SNS",
      description: "Publish to both Kafka and SNS simultaneously",
      icon: <Zap className="h-5 w-5" />,
      color: "bg-purple-500",
    },
    {
      value: "sns-sqs",
      label: "SNS + SQS",
      description: "Publish to SNS and send to SQS queue",
      icon: <Cloud className="h-5 w-5" />,
      color: "bg-blue-500",
    },
    {
      value: "kafka",
      label: "Kafka Only",
      description: "Publish message to Kafka topic only",
      icon: <Database className="h-5 w-5" />,
      color: "bg-green-500",
    },
    {
      value: "sns",
      label: "SNS Only",
      description: "Publish message to SNS topic only",
      icon: <MessageCircle className="h-5 w-5" />,
      color: "bg-yellow-500",
    },
    {
      value: "sqs",
      label: "SQS Only",
      description: "Send message to SQS queue only",
      icon: <Activity className="h-5 w-5" />,
      color: "bg-red-500",
    },
  ];

  useEffect(() => {
    checkApiHealth();
  }, []);

  const checkApiHealth = async () => {
    try {
      const response = await fetch(
        `${process.env.REACT_APP_API_URL || ""}/api/health`
      );
      const data = await response.json();
      setApiStatus(data);
    } catch (error) {
      setApiStatus({ status: "ERROR", error: error.message });
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!message.trim()) {
      showToast("Please enter a message", "error");
      return;
    }

    setLoading(true);

    try {
      let parsedMetadata = {};
      if (metadata.trim()) {
        try {
          parsedMetadata = JSON.parse(metadata);
        } catch (error) {
          showToast("Invalid JSON format in metadata", "error");
          setLoading(false);
          return;
        }
      }

      const response = await fetch(
        `${
          process.env.REACT_APP_API_URL || ""
        }/api/publisher/${selectedPublisher}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: message,
            metadata: parsedMetadata,
          }),
        }
      );

      const data = await response.json();

      if (response.ok || response.status === 207) {
        // 207 is partial success
        showToast(data.message || "Message sent successfully!", "success");

        // Determine the actual status based on response
        let entryStatus = "success";
        if (response.status === 207) {
          entryStatus = "partial";
        } else if (data.success === false) {
          entryStatus = "error";
        }

        // Add to history with proper result handling
        const historyEntry = {
          id: data.requestId || Date.now(),
          message:
            message.substring(0, 50) + (message.length > 50 ? "..." : ""),
          publisher: selectedPublisher,
          timestamp: new Date().toLocaleString(),
          status: entryStatus,
          results:
            data.results ||
            (data.result
              ? { [selectedPublisher]: { status: "success", ...data.result } }
              : null),
        };
        setHistory((prev) => [historyEntry, ...prev].slice(0, 10));

        // Reset form on full success
        if (data.success) {
          setMessage("");
          setMetadata("");
        }
      } else {
        showToast(data.error || "Failed to send message", "error");

        // Add error to history
        const historyEntry = {
          id: data.requestId || Date.now(),
          message:
            message.substring(0, 50) + (message.length > 50 ? "..." : ""),
          publisher: selectedPublisher,
          timestamp: new Date().toLocaleString(),
          status: "error",
          error: data.error,
        };
        setHistory((prev) => [historyEntry, ...prev].slice(0, 10));
      }
    } catch (error) {
      showToast("Network error: " + error.message, "error");
    } finally {
      setLoading(false);
    }
  };

  const showToast = (message, type) => {
    // Simple toast implementation
    const toast = document.createElement("div");
    toast.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
      type === "success" ? "bg-green-500" : "bg-red-500"
    } text-white`;
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
      document.body.removeChild(toast);
    }, 3000);
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case "success":
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case "partial":
        return <Clock className="h-4 w-4 text-yellow-500" />;
      case "error":
        return <XCircle className="h-4 w-4 text-red-500" />;
      default:
        return <Clock className="h-4 w-4 text-gray-500" />;
    }
  };

  const selectedOption = publisherOptions.find(
    (opt) => opt.value === selectedPublisher
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-lg shadow-xl p-6 mb-6">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">
            Message Publisher
          </h1>
          <p className="text-gray-600">
            Send messages to Kafka, SNS, and SQS services with real-time
            processing
          </p>

          {/* API Status */}
          <div className="mt-4 flex items-center space-x-2">
            <div
              className={`h-2 w-2 rounded-full ${
                apiStatus?.status === "OK" ? "bg-green-500" : "bg-red-500"
              }`}
            />
            <span className="text-sm text-gray-600">
              API Status: {apiStatus?.status || "Checking..."}
            </span>
            {apiStatus?.services && (
              <div className="text-xs text-gray-500 ml-4">
                Kafka: {apiStatus.services.kafka} | AWS:{" "}
                {apiStatus.services.aws}
              </div>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Message Form */}
          <div className="bg-white rounded-lg shadow-xl p-6">
            <h2 className="text-xl font-semibold text-gray-700 mb-4">
              Send Message
            </h2>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Publisher Selection */}
              <div>
                <label
                  htmlFor="method"
                  className="block text-sm font-medium text-gray-700 mb-2"
                >
                  Publishing Method
                </label>
                <div className="grid grid-cols-1 gap-2">
                  {publisherOptions.map((option) => (
                    <div
                      key={option.value}
                      className={`relative flex items-center p-3 border rounded-lg cursor-pointer transition-all ${
                        selectedPublisher === option.value
                          ? "border-blue-500 bg-blue-50"
                          : "border-gray-300 hover:border-gray-400"
                      }`}
                      onClick={() => setSelectedPublisher(option.value)}
                    >
                      <input
                        type="radio"
                        name="publisher"
                        value={option.value}
                        checked={selectedPublisher === option.value}
                        onChange={() => setSelectedPublisher(option.value)}
                        className="sr-only"
                      />
                      <div
                        className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-white ${option.color}`}
                      >
                        {option.icon}
                      </div>
                      <div className="ml-3 flex-1">
                        <div className="font-medium text-gray-900">
                          {option.label}
                        </div>
                        <div className="text-sm text-gray-500">
                          {option.description}
                        </div>
                      </div>
                      {selectedPublisher === option.value && (
                        <CheckCircle className="h-5 w-5 text-blue-500" />
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Message Input */}
              <div>
                <label
                  htmlFor="message"
                  className="block text-sm font-medium text-gray-700 mb-2"
                >
                  Message *
                </label>
                <textarea
                  id="message"
                  rows={4}
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Enter your message here..."
                  required
                />
              </div>

              {/* Metadata Input */}
              <div>
                <label
                  htmlFor="metadata"
                  className="block text-sm font-medium text-gray-700 mb-2"
                >
                  Metadata (JSON)
                </label>
                <textarea
                  id="metadata"
                  rows={3}
                  value={metadata}
                  onChange={(e) => setMetadata(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono text-sm"
                  placeholder='{"key": "value", "priority": "high"}'
                />
                <p className="text-xs text-gray-500 mt-1">
                  Optional JSON metadata to include with your message
                </p>
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={loading}
                className={`w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white ${
                  loading
                    ? "bg-gray-400 cursor-not-allowed"
                    : selectedOption?.color + " hover:opacity-90"
                } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors`}
              >
                {loading ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
                    Publishing...
                  </>
                ) : (
                  <>
                    <Send className="h-4 w-4 mr-2" />
                    Publish to {selectedOption?.label}
                  </>
                )}
              </button>
            </form>

            {/* Current Selection Summary */}
            {selectedOption && (
              <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                <h3 className="text-sm font-medium text-gray-700 mb-2">
                  Publishing Summary
                </h3>
                <div className="flex items-center space-x-2">
                  <div
                    className={`w-6 h-6 rounded-full flex items-center justify-center text-white ${selectedOption.color}`}
                  >
                    {selectedOption.icon}
                  </div>
                  <div className="text-sm text-gray-600">
                    {selectedOption.description}
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* History and Status */}
          <div className="space-y-6">
            {/* Message History */}
            <div className="bg-white rounded-lg shadow-xl p-6">
              <h2 className="text-xl font-semibold text-gray-700 mb-4">
                Recent Messages
              </h2>

              {history.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  <MessageCircle className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  <p>No messages sent yet</p>
                  <p className="text-sm">
                    Your message history will appear here
                  </p>
                </div>
              ) : (
                <div className="space-y-3 max-h-96 overflow-y-auto">
                  {history.map((entry) => (
                    <div
                      key={entry.id}
                      className="border border-gray-200 rounded-lg p-3 hover:bg-gray-50 transition-colors"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center space-x-2 mb-1">
                            {getStatusIcon(entry.status)}
                            <span className="text-sm font-medium text-gray-900">
                              {entry.publisher.toUpperCase()}
                            </span>
                            <span className="text-xs text-gray-500">
                              {entry.timestamp}
                            </span>
                          </div>
                          <p className="text-sm text-gray-600 mb-2">
                            {entry.message}
                          </p>

                          {/* Results */}
                          {entry.results && (
                            <div className="text-xs space-y-1">
                              {typeof entry.results === "object" &&
                              !Array.isArray(entry.results) ? (
                                Object.entries(entry.results).map(
                                  ([service, result]) => {
                                    // Handle both single service and multi-service results
                                    const isSuccess =
                                      result.status === "success" ||
                                      result.status === "fulfilled";
                                    const serviceName =
                                      service === entry.publisher
                                        ? service.toUpperCase()
                                        : service.charAt(0).toUpperCase() +
                                          service.slice(1);

                                    return (
                                      <div
                                        key={service}
                                        className="flex items-center space-x-1"
                                      >
                                        <span className="font-medium">
                                          {serviceName}:
                                        </span>
                                        {isSuccess ? (
                                          <span className="text-green-600">
                                            ✓ Success
                                          </span>
                                        ) : (
                                          <span className="text-red-600">
                                            ✗{" "}
                                            {result.error ||
                                              result.message ||
                                              "Failed"}
                                          </span>
                                        )}
                                        {/* Show additional details for successful operations */}
                                        {isSuccess && result.messageId && (
                                          <span className="text-gray-500">
                                            ({result.messageId.substring(0, 8)}
                                            ...)
                                          </span>
                                        )}
                                        {isSuccess &&
                                          result.partition !== undefined && (
                                            <span className="text-gray-500">
                                              (partition: {result.partition})
                                            </span>
                                          )}
                                      </div>
                                    );
                                  }
                                )
                              ) : (
                                <div className="text-green-600">✓ Success</div>
                              )}
                            </div>
                          )}

                          {entry.error && (
                            <div className="text-xs text-red-600 mt-1">
                              Error: {entry.error}
                            </div>
                          )}

                          {/* Show success indicator for single services when no detailed results */}
                          {!entry.results && entry.status === "success" && (
                            <div className="text-xs text-green-600">
                              ✓ Message published successfully
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {history.length > 0 && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <button
                    onClick={() => setHistory([])}
                    className="text-sm text-red-600 hover:text-red-800 transition-colors"
                  >
                    Clear History
                  </button>
                </div>
              )}
            </div>

            {/* Service Status */}
            <div className="bg-white rounded-lg shadow-xl p-6">
              <h2 className="text-xl font-semibold text-gray-700 mb-4">
                Service Status
              </h2>

              <div className="space-y-3">
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <Database className="h-5 w-5 text-green-500" />
                    <span className="font-medium">Kafka</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="h-2 w-2 bg-green-500 rounded-full" />
                    <span className="text-sm text-gray-600">Connected</span>
                  </div>
                </div>

                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <Cloud className="h-5 w-5 text-blue-500" />
                    <span className="font-medium">AWS SNS</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="h-2 w-2 bg-green-500 rounded-full" />
                    <span className="text-sm text-gray-600">Available</span>
                  </div>
                </div>

                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <Activity className="h-5 w-5 text-red-500" />
                    <span className="font-medium">AWS SQS</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="h-2 w-2 bg-green-500 rounded-full" />
                    <span className="text-sm text-gray-600">Active</span>
                  </div>
                </div>
              </div>

              <div className="mt-4 pt-4 border-t border-gray-200">
                <button
                  onClick={checkApiHealth}
                  className="text-sm text-blue-600 hover:text-blue-800 transition-colors"
                >
                  Refresh Status
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="mt-8 bg-white rounded-lg shadow-xl p-6">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between">
            <div className="mb-4 md:mb-0">
              <h3 className="text-lg font-semibold text-gray-800">
                Message Publisher System
              </h3>
              <p className="text-sm text-gray-600">
                Reliable message publishing across multiple messaging platforms
              </p>
            </div>
            <div className="flex space-x-4 text-sm text-gray-500">
              <span>API: http://localhost:4000</span>
              <span>|</span>
              <span>Workers: Running</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default MessagePublisher;
