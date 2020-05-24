Usage: eclipse-extract-software-sites.pl [OPTION]...

Options:
 -i, --in	Location of 'org.eclipse.equinox.p2.artifact.repository.prefs'
		('<eclipse dir>/p2/org.eclipse.equinox.p2.engine/profileRegistry
		/<profile>/.data/.settings/') or full path of file to read from.
		If omitted, 'org.eclipse.equinox.p2.artifact.repository.prefs'
		must be in cwd.
 -o, --out	Location to place 'eclipse-bookmarks.xml' or full path of file
		to write to.
		If omitted, output will be written to 'eclipse-bookmarks.xml'
		in cwd.
 -y, --yes	Don't ask whether to overwrite an existing output file.
 -h, --help	Print this help.
