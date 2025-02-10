#!/usr/bin/python3

import os
import argparse

SYS_USB_PATH = "/sys/bus/usb/devices"
USB_IDS_PATH = "/usr/share/misc/usb.ids"  # Path to USB vendor/product IDs file


def load_usb_ids():
    """
    Load the USB vendor and product IDs mapping from the usb.ids file.

    Returns:
        dict: A nested dictionary mapping vendor IDs to product IDs and their names.
    """
    usb_ids = {}
    if not os.path.exists(USB_IDS_PATH):
        return {}

    with open(USB_IDS_PATH, "r") as f:
        vendor_id = None
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if not line.startswith("\t"):
                # Vendor ID line
                parts = line.split(" ", 1)
                if len(parts) == 2:
                    vendor_id = parts[0]
                    usb_ids[vendor_id] = {"name": parts[1], "products": {}}
            elif vendor_id:
                # Product ID line
                parts = line.strip().split(" ", 1)
                if len(parts) == 2:
                    product_id = parts[0]
                    product_name = parts[1]
                    usb_ids[vendor_id]["products"][product_id] = product_name

    return usb_ids


def list_usb_devices(usb_ids):
    """
    List all connected USB devices with vendor and product information.

    Args:
        usb_ids (dict): Mapping of vendor and product IDs to human-readable names.

    Returns:
        list: A list of dictionaries containing device name, vendor ID, product ID, and resolved names.
    """
    devices = []
    try:
        for device_name in os.listdir(SYS_USB_PATH):
            device_path = os.path.join(SYS_USB_PATH, device_name)
            if os.path.isdir(device_path) and os.path.exists(os.path.join(device_path, "idVendor")):
                try:
                    with open(os.path.join(device_path, "idVendor"), "r") as f_vendor, \
                         open(os.path.join(device_path, "idProduct"), "r") as f_product:
                        vendor = f_vendor.read().strip()
                        product = f_product.read().strip()

                        vendor_name = usb_ids.get(vendor, {}).get("name", "Unknown Vendor")
                        product_name = usb_ids.get(vendor, {}).get("products", {}).get(product, "Unknown Product")

                        devices.append({
                            "device": device_name,
                            "vendor": vendor,
                            "vendor_name": vendor_name,
                            "product": product,
                            "product_name": product_name,
                        })
                except IOError:
                    continue
    except FileNotFoundError:
        return {"error": "USB sysfs path not found"}
    return devices


def main():
    parser = argparse.ArgumentParser(description="USB Device Manager with Name Resolution")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subparser for the "list" command
    list_parser = subparsers.add_parser("list", help="List all connected USB devices")

    # Subparser for the "reset" command
    reset_parser = subparsers.add_parser("reset", help="Reset a specific USB device")
    reset_parser.add_argument("device_path", help="Path to the USB device (e.g., /dev/bus/usb/001/002)")
    reset_parser.add_argument("--count", type=int, default=1, help="Number of reset commands to send (default: 1)")
    reset_parser.add_argument("--delay", type=float, default=0.0, help="Delay in seconds between resets (default: 0.0)")

    args = parser.parse_args()

    usb_ids = load_usb_ids()

    if args.command == "list":
        devices = list_usb_devices(usb_ids)
        if isinstance(devices, dict) and "error" in devices:
            print(devices["error"])
        else:
            for device in devices:
                print(f"Device: {device['device']}, Vendor: {device['vendor']} ({device['vendor_name']}), "
                      f"Product: {device['product']} ({device['product_name']})")
    elif args.command == "reset":
        device_path = args.device_path
        reset_count = args.count
        delay = args.delay
        result = reset_usb_device(device_path, reset_count, delay)
        if "error" in result:
            print(f"Error: {result['error']}")
        else:
            print(result["message"])


def reset_usb_device(device_path, reset_count=1, delay=0.0):
    try:
        print(f"Attempting to open device: {device_path}")
        with open(device_path, "rb+") as dev_file:
            print(f"Device {device_path} opened successfully.")
            import fcntl
            USBDEVFS_RESET = 21780  # IOCTL code for USB reset

            for i in range(reset_count):
                print(f"Sending reset command {i + 1} of {reset_count}...")
                fcntl.ioctl(dev_file, USBDEVFS_RESET)
                if i < reset_count - 1:
                    time.sleep(delay)  # Apply delay between resets if needed

        return {"message": f"Device {device_path} reset successfully {reset_count} time(s) with {delay}s delay"}
    except IOError as e:
        if "Is a directory" in str(e):
            return {"error": f"Device {device_path} appears to be a root hub and cannot be reset."}
        return {"error": f"Failed to reset device {device_path}: {e}"}


if __name__ == "__main__":
    main()
