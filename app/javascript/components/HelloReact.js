import React, { useState } from "react";

function HelloReact({ name = "World", message = "Hello from React!" }) {
  const [count, setCount] = useState(0);
  const [isVisible, setIsVisible] = useState(true);

  return React.createElement("div", {
    className: "bg-blue-50 border border-blue-200 rounded-lg p-6 max-w-md"
  }, [
    React.createElement("div", {
      className: "flex items-center justify-between mb-4",
      key: "header"
    }, [
      React.createElement("h2", {
        className: "text-xl font-semibold text-blue-900",
        key: "title"
      }, message),
      React.createElement("button", {
        onClick: () => setIsVisible(!isVisible),
        className: "text-blue-600 hover:text-blue-800 text-sm",
        key: "toggle"
      }, isVisible ? "Hide" : "Show")
    ]),
    
    isVisible && React.createElement("div", {
      className: "space-y-4",
      key: "content"
    }, [
      React.createElement("p", {
        className: "text-blue-700",
        key: "welcome"
      }, [
        "Welcome, ",
        React.createElement("strong", { key: "name" }, name),
        "! React is now working in your Rails app."
      ]),
      
      React.createElement("div", {
        className: "bg-white rounded-md p-4 border border-blue-100",
        key: "counter-section"
      }, [
        React.createElement("p", {
          className: "text-sm text-gray-600 mb-2",
          key: "counter-label"
        }, "Click counter example:"),
        React.createElement("div", {
          className: "flex items-center space-x-3",
          key: "counter-controls"
        }, [
          React.createElement("button", {
            onClick: () => setCount(count - 1),
            className: "bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded text-sm",
            key: "decrement"
          }, "-"),
          React.createElement("span", {
            className: "font-mono text-lg font-semibold",
            key: "count"
          }, count),
          React.createElement("button", {
            onClick: () => setCount(count + 1),
            className: "bg-green-500 hover:bg-green-600 text-white px-3 py-1 rounded text-sm",
            key: "increment"
          }, "+")
        ])
      ]),
      
      React.createElement("div", {
        className: "text-xs text-blue-500",
        key: "version"
      }, `This component is rendered with React ${React.version}`)
    ])
  ]);
}

export default HelloReact;
