<img src="Table%20Tool/Images.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width=128 height=128 alt="Table Tool Next icon">

# Table Tool Next

A simple CSV editor for macOS, native on Apple Silicon and Intel Macs.

Table Tool Next continues [Table Tool](https://github.com/jakob/TableTool), which was last updated in 2017. Version 2.0 rebuilds it for current macOS with a modern toolbar, full dark mode support and a universal binary.

**[Download the latest release](https://github.com/timklop/TableTool-next/releases/latest)**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Artwork/Screenshots/2026-10-29%20Table%20Tool%20Next%202.0%20dark.png">
  <img src="Artwork/Screenshots/2026-10-29%20Table%20Tool%20Next%202.0%20light.png" width=837 alt="Table Tool Next showing a customer list in a table, with the format bar at the bottom">
</picture>

The CSV format is a commonly used file format to store and exchange tabular data.
Almost all spreadsheet and database apps (e.g. Excel and Numbers) support it.
Unfortunately, not all CSV files are made equal.
CSV files use different record delimiters (comma or semicolon), character encodings, decimal separators or quoting styles.

Table Tool handles these issues automatically.
It detects the specification of a CSV file for you and displays its contents in a table view.
Using Table Tool is the easy way to create, edit and convert CSV files.

## Usage

**Open Files:**
When opening a CSV file, Table Tool detects the format specifications
(record delimiter, character encoding, etc.) automatically.
You can also set the specifications manually in the bar at the bottom of the window.
Columns are resized to fit their contents (turn this off with View › Resize Columns When Opening Files).

**Edit Files:**
Edit the contents of the cells, rows and columns of the document easily in a grid based user interface.
While editing a cell, Tab and Shift-Tab move to the next and previous cell in the row, Return and Shift-Return to the cell below and above, and ⌘-Return finishes editing.
Add and delete rows and columns from the toolbar or the Table menu (⌥⌘ and an arrow key adds a row or column in that direction).
After editing, the bar at the bottom sets how the file is saved; ticking or unticking Header moves the first row into or out of the column titles.

**Convert Files:**
Convert an existing CSV file to a different format with File › Convert….

## Installation

Table Tool Next needs macOS 12 Monterey or later.

1. Download the `.zip` from the [latest release](https://github.com/timklop/TableTool-next/releases/latest) and open it.
2. Move **Table Tool Next** to your Applications folder.
3. Open it. The app isn't notarized by Apple, so the first time macOS blocks it:
   - **macOS 15 Sequoia and later:** click *Done*, then go to System Settings › Privacy & Security, scroll down and click *Open Anyway*.
   - **macOS 12–14:** Control-click the app, choose *Open*, then click *Open* again.

Table Tool Next has its own name and bundle identifier, so it can be installed next to the original Table Tool from the Mac App Store.

## Building

Open `Table Tool.xcodeproj` in Xcode and run the *Table Tool* scheme, or build a universal release from the command line:

```
xcodebuild -project "Table Tool.xcodeproj" -scheme "Table Tool" -configuration Release -destination "generic/platform=macOS" build
```

## Credits

Table Tool was made by [Sandro Peham](https://github.com/SandroPeham),
[Andreas Aigner](https://github.com/aigi) and
[Jakob Egger](https://github.com/jakob).

Table Tool Next 2.0 was modernised by [timklop](https://github.com/timklop) with [Claude Code](https://claude.com/claude-code).

## Licence

Table Tool Next is distributed under the [MIT Licence](LICENSE).
