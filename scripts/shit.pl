#!/usr/bin/perl

# This program is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, version 2.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# copyright Tom Allen (tom@nonserviam.net)
#
# Contributors:
# Gil Goncalves (lursty@gmail.com)

no warnings 'utf8';

use strict;


use Image::Magick;
use Term::Size;
use Getopt::Long;
use Time::HiRes qw(gettimeofday tv_interval);


my $TIMESTAMP = [gettimeofday]; # Track time for debug
my $GOOD_MATCH_DISTANCE = 30;

my ($COLUMNS, $ROWS) = Term::Size::chars *STDOUT{IO};

$ROWS--; # Subtract a row for the line the user will be on.

my $SATURATION;
my $DEBUG;
my $CACHE_HIT;
my $CACHE_MISS;
my $NO_CACHE;
my $FILTER;
my $BLUR = 1;

GetOptions(
    "saturation=s", \$SATURATION,
    "debug", \$DEBUG,
    "nocache", \$NO_CACHE,
    "filter=s", \$FILTER,
    "blur=s", \$BLUR,
    "width=s", \$COLUMNS,
    "height=s", $ROWS,
);

my $filename = shift();
unless (-f $filename) {
    die "You must specify a valid filename.\n";
}

my @TIMERSTATS;

print_file_in_terminal($filename);


sub print_file_in_terminal {
    my $filename = shift;
    my $img = load_image($filename);

    log_time("Loading");

    $img = resize_image($img);

    log_time("Resizing");

    if (length($SATURATION)) {
        my $img = apply_saturation($img);

        log_time("Applying saturation to");
    }

    my $colormap = get_colormap();

    my $output = create_terminal_image($img, $colormap);

    log_time("Colormatching");

    print $output;

    log_time("Displaying");

    show_log();
}


sub log_time {
    my $action = shift;

    if ($DEBUG) {
        push @TIMERSTATS, "$action image: " . get_interval();
    }
}


sub get_interval {
    my $interval = tv_interval($TIMESTAMP, [gettimeofday]);
    $TIMESTAMP = [gettimeofday];
    return $interval;
}


sub show_log {
    if ($DEBUG) {
        unless ($NO_CACHE) {
            warn "Hit: $CACHE_HIT Miss: $CACHE_MISS\n";
        }
        warn "Timer stats:\n  " . join("\n  ", @TIMERSTATS) . "\n";
    }
}


sub load_image {
    my $filename = shift;

    my $img = new Image::Magick;
    $img->Read($filename);

    return $img;
}


sub resize_image {
    my $img = shift;

    my $geometry = $COLUMNS . "x" . ($ROWS * 2);
    if ($FILTER) {
        $img->Resize(
            'geometry' => $geometry,
            'filter' => $FILTER,
            'blur' => $BLUR,
        );
    }
    else {
        $img->Resize(
            'geometry' => $geometry,
        );
    }

    return $img;
}


sub apply_saturation {
    my $img = shift;

    $img->Modulate('saturation' => $SATURATION);

    return $img;
}


sub create_terminal_image {
    my $img      = shift;
    my $colormap = shift;

    my $width = $img->Get("width");
    my $height = $img->Get("height");
    my @map = $img->GetPixels(
        'width' => $width,
        'height' => $height,
        'x' => 0,
        'y' => 0,
        'map' => 'RGB',
        'normalize' => 'true',
    );

    my $output;
    for (my $y=0; $y < ($height -1); $y+=2) {
        for my $x ( 0 .. ($width -1 )) {
            my $bc = find_closest_match(
                $map[ ($x * 3) + ($y * $width * 3) ] * 255,
                $map[ ($x * 3) + ($y * $width * 3) + 1 ] * 255,
                $map[ ($x * 3) + ($y * $width * 3) + 2 ] * 255,
                $colormap,
            );
            my $fc = find_closest_match(
                $map[ ($x * 3) + (($y + 1) * $width * 3) ] * 255,
                $map[ ($x * 3) + (($y + 1) * $width * 3) + 1 ] * 255,
                $map[ ($x * 3) + (($y + 1) * $width * 3) + 2 ] * 255,
                $colormap,
            );
            $output .= "[38;5;" . $fc . "m[48;5;" . $bc . "m" . chr(0x2584);
        }
        $output .= "[0m\n";
    }
    return $output;
}


sub find_closest_match {
    my $red = int(shift);
    my $green = int(shift);
    my $blue = int(shift);
    my $colormap = shift;
    my %colormap = %{$colormap};
    my $image_code = join(":", $red, $green, $blue);

    my %cache;

    if (( !$NO_CACHE ) && ($cache{$image_code})) {
        $CACHE_HIT++;
        return $cache{$image_code};
    }

    my $dist  = 999999999;
    my $index = 0;
    my $boxsize = 50;

    foreach my $key (keys %colormap) {
        my ($r2, $g2, $b2) = @{$colormap{$key}};
        if ((abs($r2 - $red) > $boxsize) ||
            (abs($g2 - $green) > $boxsize) ||
            (abs($b2 - $blue) > $boxsize)) {
            next;
        }
        my $nd = sqrt(
            ($r2 - $red) ** 2 +
            ($g2 - $green) ** 2 +
            ($b2 - $blue) ** 2
        );
        if ($nd < $dist) {
            $dist  = $nd;
            $index = $key;
            if ($dist < $GOOD_MATCH_DISTANCE) {
                unless ($NO_CACHE) {
                    $CACHE_MISS++;
                    $cache{$image_code} = $index;
                }
                return $index;
            }
        }
    }

    unless ($NO_CACHE) {
        $CACHE_MISS++;
        $cache{$image_code} = $index;
    }
    return $index;
}


sub get_colormap {
    my $colormap = {
        16 => [ 0, 0, 0 ],
        17 => [ 0, 0, 95 ],
        18 => [ 0, 0, 135 ],
        19 => [ 0, 0, 175 ],
        20 => [ 0, 0, 215 ],
        21 => [ 0, 0, 255 ],
        22 => [ 0, 95, 0 ],
        23 => [ 0, 95, 95 ],
        24 => [ 0, 95, 135 ],
        25 => [ 0, 95, 175 ],
        26 => [ 0, 95, 215 ],
        27 => [ 0, 95, 255 ],
        28 => [ 0, 135, 0 ],
        29 => [ 0, 135, 95 ],
        30 => [ 0, 135, 135 ],
        31 => [ 0, 135, 175 ],
        32 => [ 0, 135, 215 ],
        33 => [ 0, 135, 255 ],
        34 => [ 0, 175, 0 ],
        35 => [ 0, 175, 95 ],
        36 => [ 0, 175, 135 ],
        37 => [ 0, 175, 175 ],
        38 => [ 0, 175, 215 ],
        39 => [ 0, 175, 255 ],
        40 => [ 0, 215, 0 ],
        41 => [ 0, 215, 95 ],
        42 => [ 0, 215, 135 ],
        43 => [ 0, 215, 175 ],
        44 => [ 0, 215, 215 ],
        45 => [ 0, 215, 255 ],
        46 => [ 0, 255, 0 ],
        47 => [ 0, 255, 95 ],
        48 => [ 0, 255, 135 ],
        49 => [ 0, 255, 175 ],
        50 => [ 0, 255, 215 ],
        51 => [ 0, 255, 255 ],
        52 => [ 95, 0, 0 ],
        53 => [ 95, 0, 95 ],
        54 => [ 95, 0, 135 ],
        55 => [ 95, 0, 175 ],
        56 => [ 95, 0, 215 ],
        57 => [ 95, 0, 255 ],
        58 => [ 95, 95, 0 ],
        59 => [ 95, 95, 95 ],
        60 => [ 95, 95, 135 ],
        61 => [ 95, 95, 175 ],
        62 => [ 95, 95, 215 ],
        63 => [ 95, 95, 255 ],
        64 => [ 95, 135, 0 ],
        65 => [ 95, 135, 95 ],
        66 => [ 95, 135, 135 ],
        67 => [ 95, 135, 175 ],
        68 => [ 95, 135, 215 ],
        69 => [ 95, 135, 255 ],
        70 => [ 95, 175, 0 ],
        71 => [ 95, 175, 95 ],
        72 => [ 95, 175, 135 ],
        73 => [ 95, 175, 175 ],
        74 => [ 95, 175, 215 ],
        75 => [ 95, 175, 255 ],
        76 => [ 95, 215, 0 ],
        77 => [ 95, 215, 95 ],
        78 => [ 95, 215, 135 ],
        79 => [ 95, 215, 175 ],
        80 => [ 95, 215, 215 ],
        81 => [ 95, 215, 255 ],
        82 => [ 95, 255, 0 ],
        83 => [ 95, 255, 95 ],
        84 => [ 95, 255, 135 ],
        85 => [ 95, 255, 175 ],
        86 => [ 95, 255, 215 ],
        87 => [ 95, 255, 255 ],
        88 => [ 135, 0, 0 ],
        89 => [ 135, 0, 95 ],
        90 => [ 135, 0, 135 ],
        91 => [ 135, 0, 175 ],
        92 => [ 135, 0, 215 ],
        93 => [ 135, 0, 255 ],
        94 => [ 135, 95, 0 ],
        95 => [ 135, 95, 95 ],
        96 => [ 135, 95, 135 ],
        97 => [ 135, 95, 175 ],
        98 => [ 135, 95, 215 ],
        99 => [ 135, 95, 255 ],
        100 => [ 135, 135, 0 ],
        101 => [ 135, 135, 95 ],
        102 => [ 135, 135, 135 ],
        103 => [ 135, 135, 175 ],
        104 => [ 135, 135, 215 ],
        105 => [ 135, 135, 255 ],
        106 => [ 135, 175, 0 ],
        107 => [ 135, 175, 95 ],
        108 => [ 135, 175, 135 ],
        109 => [ 135, 175, 175 ],
        110 => [ 135, 175, 215 ],
        111 => [ 135, 175, 255 ],
        112 => [ 135, 215, 0 ],
        113 => [ 135, 215, 95 ],
        114 => [ 135, 215, 135 ],
        115 => [ 135, 215, 175 ],
        116 => [ 135, 215, 215 ],
        117 => [ 135, 215, 255 ],
        118 => [ 135, 255, 0 ],
        119 => [ 135, 255, 95 ],
        120 => [ 135, 255, 135 ],
        121 => [ 135, 255, 175 ],
        122 => [ 135, 255, 215 ],
        123 => [ 135, 255, 255 ],
        124 => [ 175, 0, 0 ],
        125 => [ 175, 0, 95 ],
        126 => [ 175, 0, 135 ],
        127 => [ 175, 0, 175 ],
        128 => [ 175, 0, 215 ],
        129 => [ 175, 0, 255 ],
        130 => [ 175, 95, 0 ],
        131 => [ 175, 95, 95 ],
        132 => [ 175, 95, 135 ],
        133 => [ 175, 95, 175 ],
        134 => [ 175, 95, 215 ],
        135 => [ 175, 95, 255 ],
        136 => [ 175, 135, 0 ],
        137 => [ 175, 135, 95 ],
        138 => [ 175, 135, 135 ],
        139 => [ 175, 135, 175 ],
        140 => [ 175, 135, 215 ],
        141 => [ 175, 135, 255 ],
        142 => [ 175, 175, 0 ],
        143 => [ 175, 175, 95 ],
        144 => [ 175, 175, 135 ],
        145 => [ 175, 175, 175 ],
        146 => [ 175, 175, 215 ],
        147 => [ 175, 175, 255 ],
        148 => [ 175, 215, 0 ],
        149 => [ 175, 215, 95 ],
        150 => [ 175, 215, 135 ],
        151 => [ 175, 215, 175 ],
        152 => [ 175, 215, 215 ],
        153 => [ 175, 215, 255 ],
        154 => [ 175, 255, 0 ],
        155 => [ 175, 255, 95 ],
        156 => [ 175, 255, 135 ],
        157 => [ 175, 255, 175 ],
        158 => [ 175, 255, 215 ],
        159 => [ 175, 255, 255 ],
        160 => [ 215, 0, 0 ],
        161 => [ 215, 0, 95 ],
        162 => [ 215, 0, 135 ],
        163 => [ 215, 0, 175 ],
        164 => [ 215, 0, 215 ],
        165 => [ 215, 0, 255 ],
        166 => [ 215, 95, 0 ],
        167 => [ 215, 95, 95 ],
        168 => [ 215, 95, 135 ],
        169 => [ 215, 95, 175 ],
        170 => [ 215, 95, 215 ],
        171 => [ 215, 95, 255 ],
        172 => [ 215, 135, 0 ],
        173 => [ 215, 135, 95 ],
        174 => [ 215, 135, 135 ],
        175 => [ 215, 135, 175 ],
        176 => [ 215, 135, 215 ],
        177 => [ 215, 135, 255 ],
        178 => [ 215, 175, 0 ],
        179 => [ 215, 175, 95 ],
        180 => [ 215, 175, 135 ],
        181 => [ 215, 175, 175 ],
        182 => [ 215, 175, 215 ],
        183 => [ 215, 175, 255 ],
        184 => [ 215, 215, 0 ],
        185 => [ 215, 215, 95 ],
        186 => [ 215, 215, 135 ],
        187 => [ 215, 215, 175 ],
        188 => [ 215, 215, 215 ],
        189 => [ 215, 215, 255 ],
        190 => [ 215, 255, 0 ],
        191 => [ 215, 255, 95 ],
        192 => [ 215, 255, 135 ],
        193 => [ 215, 255, 175 ],
        194 => [ 215, 255, 215 ],
        195 => [ 215, 255, 255 ],
        196 => [ 255, 0, 0 ],
        197 => [ 255, 0, 95 ],
        198 => [ 255, 0, 135 ],
        199 => [ 255, 0, 175 ],
        200 => [ 255, 0, 215 ],
        201 => [ 255, 0, 255 ],
        202 => [ 255, 95, 0 ],
        203 => [ 255, 95, 95 ],
        204 => [ 255, 95, 135 ],
        205 => [ 255, 95, 175 ],
        206 => [ 255, 95, 215 ],
        207 => [ 255, 95, 255 ],
        208 => [ 255, 135, 0 ],
        209 => [ 255, 135, 95 ],
        210 => [ 255, 135, 135 ],
        211 => [ 255, 135, 175 ],
        212 => [ 255, 135, 215 ],
        213 => [ 255, 135, 255 ],
        214 => [ 255, 175, 0 ],
        215 => [ 255, 175, 95 ],
        216 => [ 255, 175, 135 ],
        217 => [ 255, 175, 175 ],
        218 => [ 255, 175, 215 ],
        219 => [ 255, 175, 255 ],
        220 => [ 255, 215, 0 ],
        221 => [ 255, 215, 95 ],
        222 => [ 255, 215, 135 ],
        223 => [ 255, 215, 175 ],
        224 => [ 255, 215, 215 ],
        225 => [ 255, 215, 255 ],
        226 => [ 255, 255, 0 ],
        227 => [ 255, 255, 95 ],
        228 => [ 255, 255, 135 ],
        229 => [ 255, 255, 175 ],
        230 => [ 255, 255, 215 ],
        231 => [ 255, 255, 255 ],
        232 => [ 8, 8, 8 ],
        233 => [ 18, 18, 18 ],
        234 => [ 28, 28, 28 ],
        235 => [ 38, 38, 38 ],
        236 => [ 48, 48, 48 ],
        237 => [ 58, 58, 58 ],
        238 => [ 68, 68, 68 ],
        239 => [ 78, 78, 78 ],
        240 => [ 88, 88, 88 ],
        241 => [ 98, 98, 98 ],
        242 => [ 108, 108, 108 ],
        243 => [ 118, 118, 118 ],
        244 => [ 128, 128, 128 ],
        245 => [ 138, 138, 138 ],
        246 => [ 148, 148, 148 ],
        247 => [ 158, 158, 158 ],
        248 => [ 168, 168, 168 ],
        249 => [ 178, 178, 178 ],
        250 => [ 188, 188, 188 ],
        251 => [ 198, 198, 198 ],
        252 => [ 208, 208, 208 ],
        253 => [ 218, 218, 218 ],
        254 => [ 228, 228, 228 ],
        255 => [ 238, 238, 238 ],
    };
    return $colormap;
}
