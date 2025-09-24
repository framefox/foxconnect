import React, { useState } from "react"

function HelloReact({ name = "World", message = "Hello from React!" }) {
  const [count, setCount] = useState(0)
  const [isVisible, setIsVisible] = useState(true)

  return (
    <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 max-w-md">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-blue-900">
          {message}
        </h2>
        <button
          onClick={() => setIsVisible(!isVisible)}
          className="text-blue-600 hover:text-blue-800 text-sm"
        >
          {isVisible ? 'Hide' : 'Show'}
        </button>
      </div>
      
      {isVisible && (
        <div className="space-y-4">
          <p className="text-blue-700">
            Welcome, <strong>{name}</strong>! React is now working in your Rails app.
          </p>
          
          <div className="bg-white rounded-md p-4 border border-blue-100">
            <p className="text-sm text-gray-600 mb-2">
              Click counter example:
            </p>
            <div className="flex items-center space-x-3">
              <button
                onClick={() => setCount(count - 1)}
                className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded text-sm"
              >
                -
              </button>
              <span className="font-mono text-lg font-semibold">
                {count}
              </span>
              <button
                onClick={() => setCount(count + 1)}
                className="bg-green-500 hover:bg-green-600 text-white px-3 py-1 rounded text-sm"
              >
                +
              </button>
            </div>
          </div>
          
          <div className="text-xs text-blue-500">
            This component is rendered with React {React.version}
          </div>
        </div>
      )}
    </div>
  )
}

export default HelloReact
