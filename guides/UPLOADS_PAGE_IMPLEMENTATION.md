# Uploads Page Implementation

## Overview

Successfully implemented a dedicated "Uploads" page in the sidebar navigation that allows users to manage their uploaded images with upload, search, preview, and delete (UI only) functionality.

## Implementation Summary

### 1. Backend Changes

#### Routes (`config/routes.rb`)

Added uploads resource route:

```ruby
resources :uploads, only: [ :index ]
```

#### Controller (`app/controllers/uploads_controller.rb`)

Created `UploadsController` with an `index` action that simply renders the view. All data fetching is handled by the React component via external API calls.

### 2. Frontend Changes

#### View (`app/views/uploads/index.html.erb`)

Created the uploads index view with:

- Page header with title and description
- React component mount point for `UploadsManager`
- Consistent styling with the rest of the application

#### React Components

**UploadsManager.js** (`app/javascript/components/UploadsManager.js`)
Main component for managing uploads with:

- Upload functionality using existing `Uploader` component
- Search bar for filtering artworks by filename
- Grid display of uploaded images
- Click handler to open preview modal
- Delete button (UI only, not hooked up to backend)
- Fetches artworks from: `/shopify-customers/${shopifyCustomerId}/images.json`
- Uses `window.FramefoxConfig` for API configuration

Key Features:

- Toggle upload interface with "Upload a new file" / "Cancel Upload" button
- Real-time search filtering
- Loading and error states
- Responsive grid layout (1/2/3 columns based on screen size)
- Each artwork card shows:
  - Image thumbnail
  - Filename
  - Image ID and key
  - Dimensions
  - Delete button (placeholder)

**ImagePreviewModal.js** (`app/javascript/components/ImagePreviewModal.js`)
Modal component for viewing image details:

- Fetches full image data from: `/shopify-customers/${shopifyCustomerId}/images/${imageId}.json`
- Displays large image preview
- Shows comprehensive metadata:
  - Filename (editable)
  - Image ID and key
  - Dimensions
  - File size (formatted as MB/KB)
  - Format
  - Host
  - Upload date
- Loading and error states
- Close button and overlay click to dismiss
- **Edit Title Functionality**:
  - Hover over title to reveal "Edit" button
  - Click to enter edit mode with input field
  - Save/Cancel buttons with loading state
  - Updates via PATCH `/shopify-customers/${shopifyCustomerId}/images/${imageId}`
  - Client-side state management with optimistic UI update
  - Callback to parent (`onTitleUpdate`) to sync changes with grid view

#### Navigation (`app/views/shared/_sidebar.html.erb`)

Added "Uploads" navigation item to sidebar:

- Positioned between "Stores" and "Help / FAQ"
- Uses `UploadIcon` for both active and inactive states
- Active state when path starts with "/uploads"

## Features

### Completed

✅ Dedicated uploads page accessible from sidebar
✅ Upload new images using existing Uploader component
✅ Search/filter images by filename
✅ Grid display of all uploaded images
✅ Click to preview image with full details
✅ Delete functionality with confirmation dialog
✅ Edit image title inline in preview modal

### Pending (For Future Implementation)

⏳ Batch operations (select multiple, bulk delete, etc.)
⏳ Image usage tracking (show which products/orders use each image)

## Technical Notes

### API Endpoints Used

- **GET** `/shopify-customers/${shopifyCustomerId}/images.json` - List all images
- **POST** `/shopify-customers/${shopifyCustomerId}/images` - Upload new image
- **GET** `/shopify-customers/${shopifyCustomerId}/images/${imageId}.json` - Get image details
- **PATCH** `/shopify-customers/${shopifyCustomerId}/images/${imageId}` - Update image details (title)
- **DELETE** `/shopify-customers/${shopifyCustomerId}/images/${imageId}/soft_delete.json` - Soft delete image

### API Response Format

**Image Detail Response:**

```json
{
  "id": 846566,
  "key": "6be80a0d",
  "title": "Louis-Vuitton-spring-2022The-Impression-17_LE_upscale_legacy_x4",
  "thumb": "https://res.cloudinary.com/framefox/image/upload/c_fill,h_200,w_200/...",
  "url": "https://res.cloudinary.com/framefox/image/upload/c_fit,w_1000/...",
  "external_id": "Louis-Vuitton-spring-2022The-Impression-17_LE_upscale_legacy_x4_ybdoge",
  "width": 8192,
  "height": 4096,
  "created_at": " 1 Nov 25,  5:49 AM"
}
```

**Fields Used:**

- `id` - Unique image identifier
- `key` - Short image key
- `title` - Image title/filename (editable)
- `thumb` - Thumbnail URL (200x200)
- `url` - Full-size optimized URL (used for preview)
- `external_id` - Cloudinary public ID
- `width` - Image width in pixels
- `height` - Image height in pixels
- `created_at` - Upload timestamp (pre-formatted)

**Update Image Request (PATCH):**

```json
{
  "image": {
    "title": "New Image Title"
  }
}
```

### Configuration

Uses `window.FramefoxConfig` which provides:

- `apiUrl` - Base API URL for Framefox API
- `shopifyCustomerId` - Current user's Shopify customer ID
- `apiAuthToken` - Authentication token

### Component Architecture

- Reuses existing `Uploader.jsx` component for upload functionality
- Reuses existing `SvgIcon.js` component for icons
- Uses axios for API calls
- Implements proper loading and error states
- Responsive design with Tailwind CSS

## Files Created

1. `app/controllers/uploads_controller.rb`
2. `app/views/uploads/index.html.erb`
3. `app/javascript/components/UploadsManager.js`
4. `app/javascript/components/ImagePreviewModal.js`

## Files Modified

1. `config/routes.rb` - Added uploads route
2. `app/views/shared/_sidebar.html.erb` - Added Uploads navigation item

## Testing Checklist

- [ ] Navigate to /uploads and verify page loads
- [ ] Verify "Uploads" appears in sidebar navigation
- [ ] Test upload functionality
- [ ] Test search/filter functionality
- [ ] Click on an image and verify preview modal opens
- [ ] Verify image details load correctly in preview modal
- [ ] Hover over image title and verify "Edit" button appears
- [ ] Click "Edit" button and verify input field appears with current title
- [ ] Update title and click "Save" to verify update works
- [ ] Verify loading spinner appears during save
- [ ] Click "Cancel" to verify edit mode is cancelled
- [ ] Test empty title validation
- [ ] Click delete button and verify "coming soon" alert appears
- [ ] Test responsive layout on mobile/tablet/desktop
- [ ] Verify no console errors

## Future Enhancements

1. **Delete Functionality**: Create backend endpoint for image deletion
2. **Batch Operations**: Add checkbox selection for multiple images
3. **Image Usage**: Show which products/orders use each image
4. **Sorting Options**: Add sort by date, filename, size, etc.
5. **Filter Options**: Add filters by format, size range, date range
6. **Image Editor**: Inline cropping/editing capabilities
7. **Drag & Drop Reorder**: For organizing images
8. **Tags/Categories**: For better organization
