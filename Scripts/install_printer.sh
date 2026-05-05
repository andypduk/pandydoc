#!/bin/bash
#
# PandyDoc CUPS Printer Installation Script
# Run with: sudo ./install_printer.sh
#

set -e

PRINTER_NAME="PandyDoc"
BACKEND_DIR="/Library/Printers/PandyDoc"
BACKEND_PATH="$BACKEND_DIR/pandydoc"
PPD_DIR="/Library/Printers/PPDs/Contents/Resources"
PPD_FILE="$PPD_DIR/PandyDoc.ppd"
INCOMING_DIR="$HOME/Library/Application Support/PandyDoc/Incoming"

echo "========================================="
echo " PandyDoc Printer Installation"
echo "========================================="
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$BACKEND_DIR"
mkdir -p "$PPD_DIR"
mkdir -p "$INCOMING_DIR"

# Set permissions for incoming directory
chmod 755 "$INCOMING_DIR"
chown "$SUDO_USER:staff" "$INCOMING_DIR"

# Create CUPS backend script
echo "Creating CUPS backend..."
cat > "$BACKEND_PATH" << 'BACKEND_EOF'
#!/bin/bash
#
# PandyDoc CUPS Backend
# Receives print jobs and saves as PDF to PandyDoc
#

# CUPS backend parameters:
# $1 = job-id
# $2 = user
# $3 = title
# $4 = copies
# $5 = options
# $6 = [file] (may be empty for stdin)

JOBTITLE="${3:-PandyDoc_Print}"
TIMESTAMP=$(date +%s)
RANDOM_ID=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')
OUTPUT_DIR="$HOME/Library/Application Support/PandyDoc/Incoming"
OUTPUT_FILE="$OUTPUT_DIR/${JOBTITLE// /_}_${TIMESTAMP}_${RANDOM_ID}.pdf"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Copy or receive the PDF data
if [ "$#" -ge 7 ] && [ -n "$7" ] && [ -f "$7" ]; then
    # File-based print job
    cp "$7" "$OUTPUT_FILE"
else
    # Stream-based print job (read from stdin)
    cat > "$OUTPUT_FILE"
fi

# Verify the file was created
if [ -f "$OUTPUT_FILE" ]; then
    echo "PDF saved to: $OUTPUT_FILE"
    echo "INFO: Document received by PandyDoc"
else
    echo "ERROR: Failed to save PDF" >&2
    exit 1
fi

# Signal the PandyDoc app if it's running
if pgrep -x "PandyDoc" > /dev/null; then
    osascript -e 'tell application "PandyDoc" to activate' 2>/dev/null || true
fi

exit 0
BACKEND_EOF

# Set permissions for backend
chmod 0755 "$BACKEND_PATH"
chown root:_lp "$BACKEND_PATH"

# Create PPD file
echo "Creating PPD file..."
cat > "$PPD_FILE" << 'PPD_EOF'
*PPD-Adobe: "4.3"
*FormatVersion: "4.3"
*FileVersion: "1.0"
*LanguageVersion: English
*LanguageEncoding: ISOLatin1
*PCFileName: "PANDYDOC.PPD"
*Product: "(PandyDoc)"
*Manufacturer: "PandyDoc"
*ModelName: "PandyDoc PDF"
*ShortNickName: "PandyDoc"
*NickName: "PandyDoc Document Manager"
*PSVersion: "(3010) 0"
*LanguageLevel: "3"
*ColorDevice: True
*DefaultColorSpace: RGB
*Throughput: "1"
*TTRasterizer: Type42
*cupsFilter: "application/pdf 0 pandydoc"
*cupsFilter: "application/postscript 0 pandydoc"
*cupsFilter: "application/vnd.cups-postscript 0 pandydoc"
*cupsFilter: "application/vnd.cups-pdf 0 pandydoc"
*OpenUI *PageSize/Media Size: PickOne
*OrderDependency: 10 AnySetup *PageSize
*DefaultPageSize: Letter
*PageSize Letter/US Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageSize A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*PageSize Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
*PageSize Executive/Executive: "<</PageSize[522 756]/ImagingBBox null>>setpagedevice"
*PageSize Tabloid/Tabloid: "<</PageSize[792 1224]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageSize
*OpenUI *PageRegion: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: Letter
*PageRegion Letter/US Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageRegion A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageRegion
*DefaultImageableArea: Letter
*ImageableArea Letter/US Letter: "18 36 594 756"
*ImageableArea A4/A4: "18 36 577 806"
*ImageableArea Legal/Legal: "18 36 594 972"
*DefaultPaperDimension: Letter
*PaperDimension Letter/US Letter: "612 792"
*PaperDimension A4/A4: "595 842"
*PaperDimension Legal/Legal: "612 1008"
*Font Helvetica: Standard "(001.006S)" Standard ROM
*Font Helvetica-Bold: Standard "(001.007S)" Standard ROM
*Font Helvetica-Oblique: Standard "(001.006S)" Standard ROM
*Font Helvetica-BoldOblique: Standard "(001.007S)" Standard ROM
*Font Courier: Standard "(002.004S)" Standard ROM
*Font Courier-Bold: Standard "(002.004S)" Standard ROM
*Font Courier-Oblique: Standard "(002.004S)" Standard ROM
*Font Courier-BoldOblique: Standard "(002.004S)" Standard ROM
*Font Times-Roman: Standard "(001.004S)" Standard ROM
*Font Times-Bold: Standard "(001.007S)" Standard ROM
*Font Times-Italic: Standard "(001.006S)" Standard ROM
*Font Times-BoldItalic: Standard "(001.007S)" Standard ROM
*Font Symbol: Special "(001.004S)" Special ROM
*Font ZapfDingbats: Special "(001.004S)" Special ROM
PPD_EOF

# Set permissions for PPD
chmod 0644 "$PPD_FILE"
chown root:wheel "$PPD_FILE"

# Restart CUPS
echo "Restarting CUPS..."
launchctl stop org.cups.cupsd
launchctl start org.cups.cupsd

# Add the printer
echo "Adding printer to CUPS..."
lpadmin -p "$PRINTER_NAME" -E -v pandydoc://localhost -P "$PPD_FILE"
cupsenable "$PRINTER_NAME"
cupsaccept "$PRINTER_NAME"

# Set default options
lpadmin -p "$PRINTER_NAME" -o printer-is-shared=false

echo ""
echo "========================================="
echo " Installation Complete!"
echo "========================================="
echo ""
echo "The 'PandyDoc' printer has been installed."
echo ""
echo "To use it:"
echo "  1. Open any application"
echo "  2. Select File > Print (or press Cmd+P)"
echo "  3. Select 'PandyDoc' from the printer list"
echo "  4. The document will be saved to PandyDoc"
echo ""
echo "Incoming documents are stored in:"
echo "  $INCOMING_DIR"
echo ""
