package NetHack::FixedMap;
use Moose;

use List::Util 'max';

has rows => (
    isa => 'ArrayRef[ArrayRef]',
    is  => 'ro',
);

has special_features => (
    isa => 'ArrayRef[ArrayRef]',
    is  => 'ro',
);

has _regions => (
    isa => 'HashRef[ArrayRef]',
    is  => 'ro',
);

has level_flags => (
    isa => 'HashRef',
    is  => 'ro',
);

has engravings => (
    isa => 'ArrayRef[ArrayRef]',
    is  => 'ro',
);

has monsters => (
    isa => 'ArrayRef[ArrayRef]',
    is => 'ro',
);

has items => (
    isa => 'ArrayRef[ArrayRef]',
    is  => 'ro',
);

has ['branch', 'name'] => (
    isa => 'Str',
    is  => 'ro',
);

has ['min_branch_z', 'max_branch_z'] => (
    isa => 'Int',
    is  => 'ro',
);

my %char_to_feat = (
    'A' => 'air',
    'B' => 'floor',
    'C' => 'cloud',
    'F' => 'bars',
    'H' => [rock => 1],
    'I' => 'ice',
    'K' => 'sink',
    'L' => 'lava',
    'P' => 'pool',
    'S' => [wall => 1],
    'T' => 'tree',
    'W' => 'water',
    '.' => 'floor',
    '#' => 'corridor',
    '\\'=> 'throne',
    ' ' => 'rock',
    '-' => 'wall',
    '|' => 'wall',
);

sub features {
    my $self = shift;
    my @features;

    for my $row (@{ $self->rows }) {
        my $x = $row->[0];
        my $y = $row->[1];
        for my $char (split //, $row->[2]) {
            my $ent = $char_to_feat{$char};

            if (ref $ent) {
                push @features, [$ent->[0], $x, $y, $ent->[1]];
            } elsif (defined $ent) {
                push @features, [$ent, $x, $y];
            }
            $x++;
        }
        $y++;
    }

    push @features, @{ $self->special_features };
    return \@features;
}

sub region {
    my $self = shift;
    my $name = shift;

    my $raw = $self->_regions->{$name} or return [];
    my @ret;

    for my $elt (@$raw) {
        if (@$elt == 2) {
            push @ret, $elt;
        } else {
            for my $x ($elt->[0]..$elt->[2]) {
                for my $y ($elt->[1]..$elt->[3]) {
                    push @ret, [$x, $y];
                }
            }
        }
    }

    return \@ret;
}

sub regions {
    my $self = shift;
    my %rgn;

    for my $name (keys %{ $self->_regions }) {
        $rgn{$name} = $self->region($name);
    }

    return \%rgn;
}

# strip variants
sub basename {
    my ($self) = @_;

    return $1 if $self->name =~ /^(.*)-(\d+)$/;
    return $1 if $self->name =~ /^[A-Z][a-z][a-z]-(\w+)$/;
    return $self->name;
}

my @all;

sub all { \@all }

__PACKAGE__->meta->make_immutable;
no Moose;

sub _get_line {
    my $sref = shift;

    1 while $$sref =~ m/\G(?:#.*)?\n/cg;

    $$sref =~ m/\G([^:\n]*:?)(.*)\n/cg or return undef;

    if ($1 eq 'MAP') {
        my @lines = ('MAP');
        push @lines, $1 while $$sref =~ m/\G(.*)\n/cg && $1 ne 'ENDMAP';

        return \@lines;
    }

    my $head = $1;
    my $tail = "$2,";

    my @bits = $head;
    push @bits, $1 || $2 || $3 || $4 while $tail =~
        m/\G\s*  (?:   " ([^"]*) "
                   |   ' ([^"]*) '
                   | (\(  [^)]*  \))
                   |     ([^,]*)
                   ) \s* ,/xg;
    #warn "vvv\n";
    #warn "$_\n" for @bits;
    #warn "^^^\n";

    return \@bits;
}

sub _str2xy {
    my $text = shift;

    return $text =~ m/\((.*),(.*)\)/;
}

sub _rect2rgn {
    my ($ox, $oy, $rect, $irreg, $map) = @_;
    die "irregular regions unimplemented" if $irreg;

    $rect =~ /\((.*),(.*),(.*),(.*)\)/ || die "ill-formed region";
    return [ $1 + $ox, $2 + $oy, $3 + $ox, $4 + $oy ];
}

sub _item2nhi {
    my ($sym, $extra) = @_;

    return "potion of $extra" if $sym eq '!';
    return $extra;
}

my %level_info = (
    minend => ['mines', 8, 9],
);

sub _parse_dgn {
    my $str = shift;
    my $sref = \$str;
    my $line;

    my (@allrows, @currows, $name, $halign, $valign, $offs_x, $offs_y, %rgn,
        @extrafeatures, @engravings, @objects, $branch, $minz, $maxz);

    while ($line = _get_line $sref) {
        my $tag = shift @$line;

        if ($tag eq 'MAZE:') {
            $name = $line->[0];
            $name =~ /^(.*?)(?:-[0-9]+)?$/;
            ($branch, $minz, $maxz) = @{ $level_info{$1} };
        } elsif ($tag eq 'GEOMETRY:') {
            ($halign, $valign) = @$line;
        } elsif ($tag eq 'MAP') {

            my $wid = max map { length } @$line;
            my $hgt = @$line;
            @currows = @$line;

            # The following ugly and wrong code taken directly from NetHack
            {
                use integer;

                # XXX assumes this NetHack is compiled for 80-column maps
                $offs_x = 3                         if $halign eq 'left';
                $offs_x = 2 + ((78 - 2 - $wid)/4)   if $halign eq 'halfleft';
                $offs_x = 2 + ((78 - 2 - $wid)/2)   if $halign eq 'center';
                $offs_x = 2 + ((78 - 2 - $wid)*3/4) if $halign eq 'halfright';
                $offs_x = 78 - $wid - 1             if $halign eq 'right';

                $offs_y = 3                         if $valign eq 'top';
                $offs_y = 2 + ((20 - 2 - $hgt)/2)   if $valign eq 'center';
                $offs_y = 20 - $hgt - 1             if $valign eq 'bottom';

                $offs_x++ unless $offs_x % 1;
                $offs_y++ unless $offs_y % 1;

                $offs_y = 0 if $hgt == 21;
                if ($offs_y < 0) {
                    $offs_y += 2;
                } elsif ($offs_y + $hgt > 21) {
                    $offs_y -= 2;
                }
            }

            for my $dy (0 .. $#{$line}) {
                push @allrows, [$offs_x, $offs_y+$dy, $line->[$dy]];
            }
        } elsif ($tag eq 'FOUNTAIN:') {
            if (my ($x, $y) = _str2xy $line->[0]) {
                push @extrafeatures, ['fountain', $x + $offs_x, $y + $offs_y];
            }
        } elsif ($tag eq 'REGION:') {
            my ($rect, $light, $type, $filled, $irreg) = @$line;

            my @l = _rect2rgn($offs_x, $offs_y, $rect, $irreg, \@allrows);

            push @{$rgn{'lit'}}, @l if ($light eq 'lit');
            push @{$rgn{'unlit'}}, @l if ($light eq 'unlit');

            push @{$rgn{'shop'}}, @l if ($type =~ /shop/);
            push @{$rgn{'temple'}}, @l if ($type eq 'temple');
        } elsif ($tag eq 'DOOR:' && (@$line == 2)) {
            (my ($x, $y) = _str2xy($line->[1])) || next;

            if (substr($currows[$y], $x, 1) eq 'S') {
                push @extrafeatures, ['wall', $x + $offs_x, $y + $offs_y,
                    $line->[0]];
            } else {
                push @extrafeatures, ['door', $x + $offs_x, $y + $offs_y,
                    $line->[0]];
            }
        } elsif ($tag eq 'STAIR:' && (@$line == 2)) {
            (my ($x,$y) = _str2xy($line->[0])) || next;

            push @extrafeatures, ['stairs' . $line->[1],
                $x+$offs_x, $y+$offs_y, 0];
        } elsif ($tag eq 'NON_DIGGABLE:') {
            push @{$rgn{'nondig'}}, _rect2rgn($offs_x, $offs_y, $line->[0]);
        } elsif ($tag eq 'ENGRAVING:') {
            (my ($x,$y) = _str2xy($line->[0])) || next;

            push @engravings, [$x+$offs_x, $y+$offs_y,
                ($line->[1] eq 'engrave') ? 'engraved' : 'burned', $line->[2]];
        } elsif ($tag eq 'OBJECT:' && (@$line == 3)) {
            my ($sym, $type, $pos) = @$line;
            (my ($x, $y) = _str2xy($pos)) || next;
            next if $type eq 'random'; #XXX NHI doesn't do class-types yet

            push @objects, [ _item2nhi($sym, $type), $x+$offs_x, $y+$offs_y ];
        } elsif ($tag eq 'TRAP:' && $line->[0] eq 'random' && $line->[1] eq 'random') {
        } elsif ($tag eq 'MONSTER:') {
            # XXX monster tracking isn't in yet
        } else {
            die "Unhandled tag $tag";
        }
    }

    push @all, __PACKAGE__->new(
        rows => \@allrows,
        special_features => \@extrafeatures,
        _regions => \%rgn,
        level_flags => {},
        engravings => \@engravings,
        monsters => [],
        items => \@objects,
        branch => $branch,
        min_branch_z => $minz,
        max_branch_z => $maxz,
    );
}

_parse_dgn <<END ;
# Mine end level variant 2
# "Gnome King's Wine Cellar"
#
MAZE: "minend-2", ' '
GEOMETRY:center,center
MAP
---------------------------------------------------------------------------
|...................................................|                     |
|.|---------S--.--|...|--------------------------|..|                     |
|.||---|   |.||-| |...|..........................|..|                     |
|.||...| |-|.|.|---...|.............................|                ..   |
|.||...|-|.....|....|-|..........................|..|.               ..   |
|.||.....|-S|..|....|............................|..|..                   |
|.||--|..|..|..|-|..|----------------------------|..|-.                   |
|.|   |..|..|....|..................................|...                  |
|.|   |..|..|----|..-----------------------------|..|....                 |
|.|---|..|--|.......|----------------------------|..|.....                |
|...........|----.--|......................|     |..|.......              |
|-----------|...|.| |------------------|.|.|-----|..|.....|..             |
|-----------|.{.|.|--------------------|.|..........|.....|....           |
|...............|.S......................|-------------..-----...         |
|.--------------|.|--------------------|.|.........................       |
|.................|                    |.....................|........    |
---------------------------------------------------------------------------
ENDMAP

# Dungeon Description
FOUNTAIN:(14,13)
REGION:(23,03,48,06),lit,"ordinary"
REGION:(21,06,22,06),lit,"ordinary"
REGION:(14,04,14,04),unlit,"ordinary"
REGION:(10,05,14,08),unlit,"ordinary"
REGION:(10,09,11,09),unlit,"ordinary"
REGION:(15,08,16,08),unlit,"ordinary"
# Secret doors
DOOR:locked,(12,02)
DOOR:locked,(11,06)
# Stairs
STAIR:(36,04),up
# Non diggable walls
NON_DIGGABLE:(00,00,52,17)
NON_DIGGABLE:(53,00,74,00)
NON_DIGGABLE:(53,17,74,17)
NON_DIGGABLE:(74,01,74,16)
NON_DIGGABLE:(53,07,55,07)
NON_DIGGABLE:(53,14,61,14)
# The Gnome King's wine cellar.
ENGRAVING:(12,03),engrave,"You are now entering the Gnome King's wine cellar."
ENGRAVING:(12,04),engrave,"Trespassers will be persecuted!"
OBJECT:'!',"booze",(10,07)
OBJECT:'!',"booze",(10,07)
OBJECT:'!',random,(10,07)
OBJECT:'!',"booze",(10,08)
OBJECT:'!',"booze",(10,08)
OBJECT:'!',random,(10,08)
OBJECT:'!',"booze",(10,09)
OBJECT:'!',"booze",(10,09)
OBJECT:'!',"object detection",(10,09)
# Objects
# The Treasure chamber...
OBJECT:'*',"diamond",(69,04)
OBJECT:'*',random,(69,04)
OBJECT:'*',"diamond",(69,04)
OBJECT:'*',random,(69,04)
OBJECT:'*',"emerald",(70,04)
OBJECT:'*',random,(70,04)
OBJECT:'*',"emerald",(70,04)
OBJECT:'*',random,(70,04)
OBJECT:'*',"emerald",(69,05)
OBJECT:'*',random,(69,05)
OBJECT:'*',"ruby",(69,05)
OBJECT:'*',random,(69,05)
OBJECT:'*',"ruby",(70,05)
OBJECT:'*',"amethyst",(70,05)
OBJECT:'*',random,(70,05)
OBJECT:'*',"amethyst",(70,05)
OBJECT:'*',"luckstone",(70,05)
# Scattered gems...
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'*',random,random
OBJECT:'(',random,random
OBJECT:'(',random,random
OBJECT:random,random,random
OBJECT:random,random,random
OBJECT:random,random,random
# Random traps
TRAP:random,random
TRAP:random,random
TRAP:random,random
TRAP:random,random
TRAP:random,random
TRAP:random,random
# Random monsters.
MONSTER:'G',"gnome king",random
MONSTER:'G',"gnome lord",random
MONSTER:'G',"gnome lord",random
MONSTER:'G',"gnome lord",random
MONSTER:'G',"gnomish wizard",random
MONSTER:'G',"gnomish wizard",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'G',"gnome",random
MONSTER:'h',"hobbit",random
MONSTER:'h',"hobbit",random
MONSTER:'h',"dwarf",random
MONSTER:'h',"dwarf",random
MONSTER:'h',"dwarf",random
MONSTER:'h',random,random
END

1;

__END__
=head1 NAME

NetHack::FixedMap - Fixed level data for NetHack

=head1 SYNOPSIS

 use NetHack::FixedMap;

 my $map = NetHack::FixedMap->by_name('soko4-2');

 print "$_\n" for (@{ $map->rows });

=head1 DESCRIPTION

This is a database of the fixed parts of maps, suitable for use in bots etc.

=head1 METHODS

=head2 rows :: ArrayRef[Str]

The rows of the map, expressed in lev_comp(6)-like notation.

=head2 features :: ArrayRef[ArrayRef]

The isolated features; each entry is of the form [type, x, y, optional].  Possible features:

    tree
    wall       Optional is 1 if secret door
    rock       Optional is 1 if secret cooridor
    door       Optional is initial state (closed, open, locked
    pool
    moat
    water
    portcullis
    lava
    bars
    corridor
    floor
    trap       Optional is type (rust, antimagic, etc)
    stairsup   Optional is 1 if ladder
    stairsdown Optional is 1 if ladder
    fountain
    throne
    sink
    grave
    altar      Optional is alignment, if defined
    ice
    air
    cloud

=head2 regions :: HashRef[ArrayRef]

Returns a list of multi-tile effects.  The values are lists of pairs for
all applicable tiles.

    lit         Tile is definitely lit
    unlit       Tile is definitely unlit
    shop        Tile is a guaranteed shop
    maybeshop   Tile is a chance shop
    temple      Tile is in a temple
    nondig      Tile is not diggable
    nonphase    Not phasable

=head2 level_flags :: HashRef

nomap, noteleport, hardfloor, arboreal, shortsighted

=head2 engravings :: ArrayRef[ArrayRef]

Each entry in the result is like [x, y, type, string]; type is burned,
written, engraved, melted, scrawl, graffiti.

=head2 monsters :: ArrayRef[ArrayRef]

Each entry is like [x, y, name].  Name may be a single letter if the
monster is generated by type.

=head2 items :: ArrayRef[ArrayRef]

Each entry is like [x, y, name]; the name may be a type symbol.a

=head1 INDEXES

These are all class methods.

=head2 all :: ArrayRef[NetHack::FixedMap]

=head2 by_name :: ArrayRef[NetHack::FixedMap]

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-nethack-fixedmap at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=NetHack-FixedMap>.

=head1 SEE ALSO


=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc NetHack::FixedMap

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/NetHack-FixedMap>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/NetHack-FixedMap>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=NetHack-FixedMap>

=item * Search CPAN

L<http://search.cpan.org/dist/NetHack-FixedMap>

=back

=head1 AUTHOR

  Stefan O'Rear <stefanor at cox dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Stefan O'Rear.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
