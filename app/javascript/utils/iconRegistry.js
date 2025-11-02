/**
 * Icon Registry
 * 
 * Pre-bundled SVG icons for instant rendering without API calls.
 * Common icons are imported directly into the bundle for zero-latency rendering.
 * Uncommon icons will still be fetched via the API endpoint as a fallback.
 */

// Import commonly used icons from React components
import StarFilledIcon from "../../assets/images/icons/StarFilledIcon.svg";
import StarIcon from "../../assets/images/icons/StarIcon.svg";
import UploadIcon from "../../assets/images/icons/UploadIcon.svg";
import SearchIcon from "../../assets/images/icons/SearchIcon.svg";
import DeleteIcon from "../../assets/images/icons/DeleteIcon.svg";
import ViewIcon from "../../assets/images/icons/ViewIcon.svg";
import ReplaceIcon from "../../assets/images/icons/ReplaceIcon.svg";
import PlusCircleIcon from "../../assets/images/icons/PlusCircleIcon.svg";
import ImageMagicIcon from "../../assets/images/icons/ImageMagicIcon.svg";
import CheckIcon from "../../assets/images/icons/CheckIcon.svg";
import AlertCircleIcon from "../../assets/images/icons/AlertCircleIcon.svg";
import AlertTriangleIcon from "../../assets/images/icons/AlertTriangleIcon.svg";
import XIcon from "../../assets/images/icons/XIcon.svg";
import RefreshIcon from "../../assets/images/icons/RefreshIcon.svg";
import ThumbsUpIcon from "../../assets/images/icons/ThumbsUpIcon.svg";
import SaveIcon from "../../assets/images/icons/SaveIcon.svg";
import ImageIcon from "../../assets/images/icons/ImageIcon.svg";
import ProductIcon from "../../assets/images/icons/ProductIcon.svg";
import ProductFilledIcon from "../../assets/images/icons/ProductFilledIcon.svg";
import OrderFilledIcon from "../../assets/images/icons/OrderFilledIcon.svg";
import DeliveryFilledIcon from "../../assets/images/icons/DeliveryFilledIcon.svg";
import ExternalSmallIcon from "../../assets/images/icons/ExternalSmallIcon.svg";
import StatusActiveIcon from "../../assets/images/icons/StatusActiveIcon.svg";
import ProductReferenceIcon from "../../assets/images/icons/ProductReferenceIcon.svg";
import SearchResourceIcon from "../../assets/images/icons/SearchResourceIcon.svg";

// Additional commonly used icons from ERB templates
import OrderFulfilledIcon from "../../assets/images/icons/OrderFulfilledIcon.svg";
import OrderUnfulfilledIcon from "../../assets/images/icons/OrderUnfulfilledIcon.svg";
import PackageFulfilledIcon from "../../assets/images/icons/PackageFulfilledIcon.svg";
import XCircleIcon from "../../assets/images/icons/XCircleIcon.svg";
import ChevronDownIcon from "../../assets/images/icons/ChevronDownIcon.svg";
import ChevronUpIcon from "../../assets/images/icons/ChevronUpIcon.svg";
import ChevronLeftIcon from "../../assets/images/icons/ChevronLeftIcon.svg";
import ChevronRightIcon from "../../assets/images/icons/ChevronRightIcon.svg";
import MinusIcon from "../../assets/images/icons/MinusIcon.svg";
import EditIcon from "../../assets/images/icons/EditIcon.svg";
import DuplicateIcon from "../../assets/images/icons/DuplicateIcon.svg";

/**
 * Process SVG content to add currentColor for fills and strokes
 * This mimics the behavior of the Rails svg_icon helper
 */
const processSvgForRegistry = (svgContent) => {
  let processed = svgContent;

  // Ensure SVG inherits text color by setting fill and stroke to currentColor
  processed = processed.replace(/fill="(?!none)[^"]*"/g, 'fill="currentColor"');
  processed = processed.replace(/stroke="(?!none)[^"]*"/g, 'stroke="currentColor"');

  // Add fill="currentColor" if no fill attribute exists
  if (!processed.match(/fill=/)) {
    processed = processed.replace(/<svg/, '<svg fill="currentColor"');
  }

  return processed;
};

// Registry of pre-bundled icons
export const iconRegistry = {
  StarFilledIcon: processSvgForRegistry(StarFilledIcon),
  StarIcon: processSvgForRegistry(StarIcon),
  UploadIcon: processSvgForRegistry(UploadIcon),
  SearchIcon: processSvgForRegistry(SearchIcon),
  DeleteIcon: processSvgForRegistry(DeleteIcon),
  ViewIcon: processSvgForRegistry(ViewIcon),
  ReplaceIcon: processSvgForRegistry(ReplaceIcon),
  PlusCircleIcon: processSvgForRegistry(PlusCircleIcon),
  ImageMagicIcon: processSvgForRegistry(ImageMagicIcon),
  CheckIcon: processSvgForRegistry(CheckIcon),
  AlertCircleIcon: processSvgForRegistry(AlertCircleIcon),
  AlertTriangleIcon: processSvgForRegistry(AlertTriangleIcon),
  XIcon: processSvgForRegistry(XIcon),
  RefreshIcon: processSvgForRegistry(RefreshIcon),
  ThumbsUpIcon: processSvgForRegistry(ThumbsUpIcon),
  SaveIcon: processSvgForRegistry(SaveIcon),
  ImageIcon: processSvgForRegistry(ImageIcon),
  ProductIcon: processSvgForRegistry(ProductIcon),
  ProductFilledIcon: processSvgForRegistry(ProductFilledIcon),
  OrderFilledIcon: processSvgForRegistry(OrderFilledIcon),
  DeliveryFilledIcon: processSvgForRegistry(DeliveryFilledIcon),
  ExternalSmallIcon: processSvgForRegistry(ExternalSmallIcon),
  StatusActiveIcon: processSvgForRegistry(StatusActiveIcon),
  ProductReferenceIcon: processSvgForRegistry(ProductReferenceIcon),
  SearchResourceIcon: processSvgForRegistry(SearchResourceIcon),
  OrderFulfilledIcon: processSvgForRegistry(OrderFulfilledIcon),
  OrderUnfulfilledIcon: processSvgForRegistry(OrderUnfulfilledIcon),
  PackageFulfilledIcon: processSvgForRegistry(PackageFulfilledIcon),
  XCircleIcon: processSvgForRegistry(XCircleIcon),
  ChevronDownIcon: processSvgForRegistry(ChevronDownIcon),
  ChevronUpIcon: processSvgForRegistry(ChevronUpIcon),
  ChevronLeftIcon: processSvgForRegistry(ChevronLeftIcon),
  ChevronRightIcon: processSvgForRegistry(ChevronRightIcon),
  MinusIcon: processSvgForRegistry(MinusIcon),
  EditIcon: processSvgForRegistry(EditIcon),
  DuplicateIcon: processSvgForRegistry(DuplicateIcon),
};

/**
 * Check if an icon exists in the registry
 */
export const hasIcon = (name) => {
  return iconRegistry.hasOwnProperty(name);
};

/**
 * Get an icon from the registry
 * Returns the SVG content if found, null otherwise
 */
export const getIcon = (name) => {
  return iconRegistry[name] || null;
};

// Deprecated alias for backwards compatibility
export const getIconFromRegistry = getIcon;
