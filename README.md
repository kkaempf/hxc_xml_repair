# HxC XML repair

## Motivation

When reading raw floppy disks with tools like
[Kryoflux](https://www.kryoflux.com) bad sectors are just left out.

This gets problematic when you want to extract data from resulting
image files. These seek a specific track/side/sector (translated to
an offset into the image file) and ... fail if sectors are missing.

One possible way to repair is the HxC XML format, where you can
freely edit tracks and sectors. However, the XML format tracks
`track_offset` and `sector_offset` and this is where editing gets
tricky.

## Workflow (with Kryoflux)

### Prerequisites

- dtc, Kryoflux command line tool, [download page](https://kryoflux.com/?page=download)

- hxcfe, HxC command line tool, from the HxCFloppyEmulator software.
  [download](https://hxc2001.com/download/floppy_drive_emulator), [source](https://sourceforge.net/p/hxcfloppyemu/code/HEAD/tree/HxCFloppyEmulator), [RPMs](https://build.opensuse.org/project/show/home:kwk:HxCFloppyEmulator)

- hxc_xml_repair.rb

### Step-by-step

* Read a floppy disk in 'raw' (flux traversal) mode

(double sided, 80 tracks, data written to `disk/trackTT.S.raw` - TT =
track number, S = side number)

> dtc -p -g2 -r10 -t10 -fdisk/track -i0 -e79

(Optionally) visually inspect the result with the HxC GUI. [PDF download](https://hxc2001.com/download/floppy_drive_emulator/HxC_Floppy_Emulator_Software_User_Manual_ENG.pdf)

* Convert to XML format

> hxcfe -finput:disk/track00.0.raw -foutput:disk.xml -conv:GENERIC_XML

* Repair missing sectors (will be filled with 0)

> ruby hxc_xml_repair.rb disk.xml > repaired.xml

* Convert to image format

> hxcfe -finput:repaired.xml -foutput:disk.img -conv:RAW_LOADER


Now e.g. [cpmtools](http://www.moria.de/~michael/cpmtools) can be used to
copy files off this image. (Well, if the image is a CP/M disk :wink:)
