import React, { useState } from "react";

function HelloWorld({ productTitle = "Product", productId = "N/A" }) {
  const [message, setMessage] = useState("Hello from React on Product Page!");
  const [isExpanded, setIsExpanded] = useState(false);

  const messages = [
    "Hello from React on Product Page!",
    "React is working perfectly!",
    "Interactive components are ready!",
    "Welcome to the future of web apps!",
  ];

  const cycleMessage = () => {
    const currentIndex = messages.indexOf(message);
    const nextIndex = (currentIndex + 1) % messages.length;
    setMessage(messages[nextIndex]);
  };

  return (
    <div className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-green-900">
          React HelloWorld Component
        </h3>
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="text-green-600 hover:text-green-800 text-sm font-medium"
        >
          {isExpanded ? "Collapse" : "Expand"}
        </button>
      </div>

      <div className="space-y-4">
        <div className="bg-white rounded-md p-4 border border-green-100">
          <p className="text-green-700 font-medium">{message}</p>
          <button
            onClick={cycleMessage}
            className="mt-2 bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm transition-colors"
          >
            Change Message
          </button>
        </div>

        {isExpanded && (
          <div className="bg-white rounded-md p-4 border border-green-100 space-y-3">
            <div className="text-sm text-gray-600">
              <p>
                <strong>Product:</strong> {productTitle}
              </p>
              <p>
                <strong>Product ID:</strong> {productId}
              </p>
              <p>
                <strong>React Version:</strong> {React.version}
              </p>
            </div>

            <div className="pt-2 border-t border-green-100">
              <p className="text-xs text-green-600">
                This React component is rendered on the product show page and
                receives product data as props from the Rails backend.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default HelloWorld;
