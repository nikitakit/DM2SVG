#!/usr/bin/perl -w
#####
#
#   DigiSVG.pl
#   written by Kevin Lindsey
#   copyright 2005
#
#####

if (@ARGV) {
    process_file(shift);
} else {
    print STDERR "usage: $0 <dhw-file>";
}


#####
#
#   process_file
#
#####
sub process_file {
    my $file = shift;
    
    if (open INPUT, $file) {
        binmode(INPUT);

        my $height = emit_header();

        my $layer = "layer1";
        my $timestamp = 0;

        my $svg_element = "<g inkscape:groupmode='layer' id='$layer'>";
        
        while (not eof(INPUT)) {
            my $tag = read_byte();
            
            if ($tag >= 128) {
                if ($tag == 0x90) {
                    # emit the current svg element
                    $svg_element = emit_element($svg_element);

                    # close the last layer
                    $svg_element = "</g>";
                    $svg_element = emit_element($svg_element);

                    # start a new layer
                    $layer = "layer" . ( read_byte() + 1 );
                    $timestamp = 0;
                    $svg_element = "<g inkscape:groupmode='layer' id='$layer'>";
                } elsif ($tag == 0x88) {
                    $timestamp += read_timestamp();
                } else {
                    # emit the current svg element
                    $svg_element = emit_element($svg_element);

                    my @coords;

                    # pen down
                    while (not eof(INPUT)) {
                        push @coords, read_point($height);
                        last if peek_byte() >= 128;
                    }

                    # pen up
                    read_byte();
                    push @coords, read_point($height);
                    my $points = gen_polyline_points(\@coords);
                    $svg_element = "<polyline points='$points' dm:timestamp='$timestamp' />";
                }
            } else {
                print STDERR "Unsupported tag: $tag\n";
            }
        }

        emit_footer();

        close INPUT;
    } else {
        print STDERR "Unable to open $file: $!";
    }
}

#####
#
#   peek_byte
#
#####
sub peek_byte {
    my $cur_pos = tell(INPUT);
    my $result = read_byte();

    seek(INPUT, $cur_pos, 0);
    
    return $result;
}

#####
#
#   read_byte
#
#####
sub read_byte {
    my $data;

    read INPUT, $data, 1;
    
    return unpack("C", $data);
}

#####
#
#   read_point
#
#####
sub read_point {
    my $ymax = shift;
    my $data;

    read INPUT, $data, 4;

    my ($x1, $x2, $y1, $y2) =
        unpack("CCCC", $data);
    my $x = $x1 | $x2 << 7;
    my $y = $y1 | $y2 << 7;

    return [$x, $ymax - $y];
}

#####
#
#   read_timestamp
#
#####
sub read_timestamp {
    return read_byte() * 20;
}

#####
#
#   emit_header
#
#####
sub emit_header {
    my $data;

    read INPUT, $data, 40;

    my ($id, $version, $width, $height, $page_type) =
        unpack("A32CSSC", $data);

    print STDOUT <<EOF;
<svg viewBox="0 0 $width $height" fill="none" stroke="black" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
  xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
  xmlns:dm="http://github.com/nikitakit/DM2SVG" >
    <metadata>
      <dm:page
        id = "$id"
        version = "$version"
        width = "$width"
        height = "$height"
        page_type = "$page_type" >
      </dm:page>
    </metadata>
    <rect width="$width" height="$height" fill="aliceblue"/>
EOF

    return $height;
}

#####
#
#   emit_element
#
#####
sub emit_element {
    my $message = shift;
    
    if ($message) {
        print STDOUT "$message \n";
    }
    return ""

}

#####
#
#   gen_polyline_points
#
#####
sub gen_polyline_points {
    my $coords = shift;
    my @points = map {
        $_->[0] . "," . $_->[1];
    } @$coords;
    my $data = join(" ", @points);

    return "$data"

}

#####
#
#   emit_footer
#
#####
sub emit_footer {
    print STDOUT <<EOF;
</svg>
EOF
}
