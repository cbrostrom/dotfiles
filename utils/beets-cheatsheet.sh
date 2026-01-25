#!/usr/bin/env bash
# Beets Quick Reference - Common Commands

cat << 'EOF'
╔═══════════════════════════════════════════════╗
║           BEETS QUICK REFERENCE               ║
╚═══════════════════════════════════════════════╝

📥 IMPORTING
────────────────────────────────────────────────
beet import /path/to/music          Import music
beet import -A /path/to/album       Import as-is (no tagging)
beet import -s /path/to/songs       Import singletons
beet import --flat                  Import without grouping

📊 BROWSING & SEARCHING
────────────────────────────────────────────────
beet ls                             List all tracks
beet ls -a                          List all albums
beet ls artist:Pulsedriver          Search by artist
beet ls album:"Future Trance"       Search by album
beet ls year:2005..2010             Search by year range
beet ls bitrate:..128000            Low quality files
beet ls genre::^$                   Files without genre
beet stats                          Collection statistics

🔍 DUPLICATES
────────────────────────────────────────────────
beet duplicates                     Find duplicates
beet duplicates -a                  Find duplicate albums
beet dup -f '$path - $bitrate'      Show with details
beet dup -m /path/to/review/        Move duplicates
beet dup -d                         Delete duplicates (careful!)

🎨 ALBUM ART
────────────────────────────────────────────────
beet fetchart                       Fetch missing art
beet fetchart -f                    Force re-fetch all
beet fetchart artist:X              Fetch for specific artist
beet embedart                       Embed art in files
beet ls -a artpath::^$              Albums without art

🏷️  METADATA EDITING
────────────────────────────────────────────────
beet modify artist=X artist=Y       Rename artist
beet modify album=X year=2005       Update album info
beet write                          Write tags to files
beet update                         Update from database
beet mbsync                         Sync with MusicBrainz

ℹ️  INFO & DIAGNOSTICS
────────────────────────────────────────────────
beet info "track title"             Show track details
beet info -a "album name"           Show album details
beet bad                            Check for corrupt files
beet missing                        Find missing tracks in albums
beet version                        Show Beets version
beet config                         Show config
beet config -p                      Show config path

🔧 MAINTENANCE
────────────────────────────────────────────────
beet update /path/to/music          Update moved files
beet move                           Organize unorganized files
beet lastgenre                      Fetch genres from Last.fm
beet replaygain                     Add ReplayGain tags

🗑️  REMOVAL
────────────────────────────────────────────────
beet remove artist:X                Remove from library
beet remove -d artist:X             Remove from library + delete files

📋 QUERY SYNTAX
────────────────────────────────────────────────
artist:X                            Exact artist
artist::X                           Artist contains X
artist:^X                           Artist starts with X
artist::^$                          Artist is empty
year:2005                           Exact year
year:2005..2010                     Year range
bitrate:..128000                    Bitrate under 128kbps
bitrate:320000..                    Bitrate 320kbps or higher

💡 TIPS
────────────────────────────────────────────────
- Use -a flag to work with albums instead of tracks
- Use -f '$path' to show file paths
- Use -f '$path - $bitrate - $format' for details
- Check import log: tail -f ~/Beets/import.log
- Backup database: cp library.db library.db.backup

🎵 Your Scripts
────────────────────────────────────────────────
./utils/install-beets.sh            Install Beets
./utils/music-import-with-beets.sh  Import all from TempMusic
./utils/music-import-album.sh NAME  Import single album
./utils/music-cleanup-analyze.sh    Analyze collection
./utils/music-cleanup-duplicates.sh Find duplicates
./utils/music-cleanup-find-low-quality.sh Find low quality

📚 Documentation: https://beets.readthedocs.io/

EOF
