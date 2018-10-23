# -------------------------------------------
# 
# screen_lock.sh
# Gere l'ecran de verrouillage.
#
# Dependances:
# scrot, imagemagick, i3lock-color
# 
# -------------------------------------------
#!/bin/sh -e

art="$HOME/.config/i3/art.png"
file_before='/tmp/screen_locked.png'
file_temp='/tmp/temp1.png'
file_end='/tmp/lock.png'

[ -f $file_before ] && rm $file_before
[ -f $file_temp ] && rm $file_temp
[ -f $file_end ] && rm $file_end

# Screenshot du bureau
scrot "$file_before"

# Gaussian Blur pour le fond
convert "$file_before" -blur 0x5 "$file_temp"

# Ajout du 1er plan
# ( Centre par defaut )
# ( En fonction du .png, ajuster geometry: left-right, then up-down)
convert "$file_temp" \
"$art" \
-gravity center \
-geometry -0+47 \
-composite \
"$file_end"

# Lance i3lock et affiche l'image
i3lock -i "$file_end" \
--insidecolor=00000000 \
--ringcolor=10b71fff \
--insidevercolor=E1E81A80 \
--ringvercolor=E1E81A40 \
--keyhlcolor=497CF2ff \
--bshlcolor=E1E81Aff \
--line-uses-inside \
-B=50 #\
# -k \
# --timepos="ix 40:iy 40"

# Eteint l'ecran apres un delai
sleep 600; pgrep i3lock && xset dpms force off

# -----------------------------------------------------
## i3lock-color
# -----------------------------------------------------
# --insidevercolor=rrggbbaa -- Inside of the circle while the password is being verified
# --insidewrongcolor=rrggbbaa -- Inside of the circle when a wrong password was entered
# --insidecolor=rrggbbaa -- Inside of the circle while typing/idle
# --ringvercolor=rrggbbaa -- Outer ring while the password is being verified
# --ringwrongcolor=rrggbbaa -- Outer ring when a wrong password was entered
# --ringcolor=rrggbbaa -- Outer ring while typing/idle
# --linecolor=rrggbbaa -- Line separating outer ring from inside of the circle
# --separatorcolor=rrggbbaa -- Lines delimiting the highlight segments
# --textcolor=rrggbbaa -- Text ("verifying", "wrong!")
# --keyhlcolor=rrggbbaa -- Keypress highlight segments
# --bshlcolor=rrggbbaa -- Backspace highlight segments
# --line-uses-ring, -r -- the line between the inside and outer ring uses the ring color for its color
# --line-uses-inside, -s -- the line between the inside and outer ring uses the inside color for its color
# -S, --screen -- specifies which display to draw the unlock indicator on
# -k, --clock -- enables the clock display.
# -B, --blur -- enables Gaussian blur
# --timestr="%H:%M:%S" -- allows custom overriding of the time format string. Accepts strftime formatting. Default is "%H:%M:%S".
# --datestr="%A, %m %Y" -- allows custom overriding of the date format string. Accepts strftime formatting. Default is "%A, %m %Y".