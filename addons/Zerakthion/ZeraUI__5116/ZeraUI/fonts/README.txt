RAJDHANI FONTS

Rajdhani Bold and SemiBold work out of the box. Choose them in
Settings > Addons > Zera UI. Nothing needs to be installed or converted.

Rajdhani-Bold-OL.slug and Rajdhani-SemiBold-OL.slug are already converted
with ESO's slugfont tool ("-outline 0.075 -round"). Fonts.xml declares them
when the game starts, so ESO draws its own outline / thick-outline and every
label is a single control. A custom .slug only gets ESO's outline when it
contains outline data AND is declared in XML at load time.

After installing or updating Zera UI, restart ESO completely once (not only
/reloadui), because Fonts.xml is read while the game starts.

The outline width is fixed in the font file, so "outline" and
"thick-outline" look the same with Rajdhani. ESO fonts are unchanged.

Optional / troubleshooting only: if a future game update changes the font
format, the former Install-Fonts.bat and related conversion scripts are
archived separately as development tools. No conversion is needed now.

Rajdhani is copyright Indian Type Foundry, licensed under the SIL Open Font
License 1.1 (see Rajdhani-OFL.txt). The .slug files are format conversions
of the original Google Fonts .ttf files and are distributed under the same
license. ESO's converter (slugfont.exe) is not redistributed.
