import React from "react";

function VideoGrid({ videos }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {videos.map((video, index) => (
        <div
          key={index}
          className="bg-white rounded-lg border border-slate-200 overflow-hidden hover:shadow-lg transition-shadow duration-200 cursor-pointer group"
        >
          {/* Video Thumbnail */}
          <div className="relative bg-slate-200 aspect-video flex items-center justify-center overflow-hidden">
            {/* Placeholder gradient background */}
            <div className="absolute inset-0 bg-gradient-to-br from-slate-300 to-slate-400"></div>

            {/* Play button overlay */}
            <div className="relative z-10 w-16 h-16 bg-white bg-opacity-90 rounded-full flex items-center justify-center group-hover:bg-opacity-100 group-hover:scale-110 transition-all duration-200 shadow-lg">
              <svg
                className="w-8 h-8 text-slate-800 ml-1"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>

            {/* Duration badge */}
            <div className="absolute bottom-2 right-2 bg-black bg-opacity-75 text-white text-xs font-medium px-2 py-1 rounded">
              {video.duration}
            </div>
          </div>

          {/* Video Info */}
          <div className="p-4">
            <h3 className="text-lg font-semibold text-slate-900 mb-2 group-hover:text-blue-600 transition-colors">
              {video.title}
            </h3>
            <p className="text-sm text-slate-600 line-clamp-2">
              {video.description}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}

export default VideoGrid;
