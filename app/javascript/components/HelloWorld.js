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

  return React.createElement("div", {
    className: "bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-lg p-6"
  }, [
    React.createElement("div", {
      className: "flex items-center justify-between mb-4",
      key: "header"
    }, [
      React.createElement("h3", {
        className: "text-lg font-semibold text-green-900",
        key: "title"
      }, "React HelloWorld Component"),
      React.createElement("button", {
        onClick: () => setIsExpanded(!isExpanded),
        className: "text-green-600 hover:text-green-800 text-sm font-medium",
        key: "toggle"
      }, isExpanded ? "Collapse" : "Expand")
    ]),

    React.createElement("div", {
      className: "space-y-4",
      key: "content"
    }, [
      React.createElement("div", {
        className: "bg-white rounded-md p-4 border border-green-100",
        key: "message-section"
      }, [
        React.createElement("p", {
          className: "text-green-700 font-medium",
          key: "message"
        }, message),
        React.createElement("button", {
          onClick: cycleMessage,
          className: "mt-2 bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm transition-colors",
          key: "cycle-button"
        }, "Change Message")
      ]),

      isExpanded && React.createElement("div", {
        className: "bg-white rounded-md p-4 border border-green-100 space-y-3",
        key: "expanded-content"
      }, [
        React.createElement("div", {
          className: "text-sm text-gray-600",
          key: "details"
        }, [
          React.createElement("p", { key: "product" }, [
            React.createElement("strong", { key: "product-label" }, "Product:"),
            ` ${productTitle}`
          ]),
          React.createElement("p", { key: "product-id" }, [
            React.createElement("strong", { key: "id-label" }, "Product ID:"),
            ` ${productId}`
          ]),
          React.createElement("p", { key: "react-version" }, [
            React.createElement("strong", { key: "version-label" }, "React Version:"),
            ` ${React.version}`
          ])
        ]),
        
        React.createElement("div", {
          className: "pt-2 border-t border-green-100",
          key: "description"
        }, React.createElement("p", {
          className: "text-xs text-green-600"
        }, "This React component is rendered on the product show page and receives product data as props from the Rails backend."))
      ])
    ])
  ]);
}

export default HelloWorld;