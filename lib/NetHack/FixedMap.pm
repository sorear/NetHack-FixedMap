package NetHack::FixedMap;
use Moose;

has rows => (
    isa => 'ArrayRef[Str]',
    is  => 'ro',
);

has ['rows_x', 'rows_y'] => (
    isa => 'Int',
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
    '{' => 'fountain',
    '\\'=> 'throne',
    ' ' => 'rock',
    '-' => 'wall',
    '|' => 'wall',
);

sub features {
    my $self = shift;
    my @features;

    my $y = $self->rows_y;
    for my $row (@{ $self->rows }) {
        my $x = $self->rows_x;
        for my $char (split //, $row) {
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

sub regions {
    my $self = shift;
    my %rgn;

    for my $name (keys %{ $self->_regions }) {
        my $val = $self->_regions->{$name};

        if (!ref $val->[0]) {
            my @expand;

            for my $x ($val->[0]..$val->[2]) {
                for my $y ($val->[1]..$val->[3]) {
                    push @xpand, [$x, $y];
                }
            }

            $val = \@expand;
        }

        $rgn{$name} = $val;
    }

    return \%rgn;
}

my @all;

sub all { \@all }

__PACKAGE__->meta->make_immutable;
no Moose;

sub get_line {
    my $sref = shift;

    1 while $$sref =~ m/\G#.*\n/cg;

    $$sref =~ m/\G([^:]*:?)(.*)\n/cg or return undef;

    if ($1 eq 'MAP') {
        my @lines = ('MAP');
        push @lines, $1 while $$sref =~ m/\G(.*)\n/ && $1 ne 'ENDMAP';

        return \@lines;
    }

    my $head = $1;
    my $tail = "$2,";

    my @bits = $head;
    push @bits, $1 while $tail =~ m/\G\s*["']?((?:[^,]+?|\([^)]*\))*?)['"]?\s*,/;

    return \@bits;
}

sub parse_dgn {
    my $sref = shift;
    my $line;

    my (@allrows, $name);

    while ($line = get_line $sref) {
        my $tag = $line->[0];

        if ($tag eq 'MAZE:') {
            if (@allrows || 
        $name = $line->[1] if ($tag eq 'MAZE:');

    $str =~ m/\GGEOMETRY:([a-z]*),([a-z]*)\n/cg or die "missing GEOMETRY";
    my ($halign, $valign) = ($1, $2);

    $str =~ m/\GMAP\n/cg or die "missing MAP";

    my @rows;
    while ($str =~ m/\G(.*)\n/cg and $str ne 'ENDMAP') {
        push @rows, $str;
    }

    my $wid = max map { length } @rows;
    my $hgt = @rows;

    my ($rows_x, $rows_y);

    # The following ugly and wrong code taken directly from NetHack
    {
        use integer;

        # XXX assumes this NetHack is compiled for 80-column maps
        $rows_x = 3                         if $halign eq 'left';
        $rows_x = 2 + ((78 - 2 - $wid)/4)   if $halign eq 'halfleft';
        $rows_x = 2 + ((78 - 2 - $wid)/2)   if $halign eq 'center';
        $rows_x = 2 + ((78 - 2 - $wid)*3/4) if $halign eq 'halfright';
        $rows_x = 78 - $wid - 1             if $halign eq 'right';

        $rows_y = 3                         if $valign eq 'top';
        $rows_y = 2 + ((20 - 2 - $hgt)/2)   if $valign eq 'center';
        $rows_y = 20 - $hgt - 1             if $valign eq 'bottom';

        $rows_x++ unless $rows_x % 1;
        $rows_y++ unless $rows_y % 1;

        $rows_y = 0 if $hgt == 21;
        if ($rows_y < 0) {
            $rows_y += 2;
        } elsif ($rows_y + $hgt > 21) {
            $rows_y -= 2;
        }
    }

    while(1) {
        last if ($str =~ m/\G$/cg);

        if ($str =~ m/\GFOUNTAIN:\((.*),(.*)\)\n/cg) {
            substr($rows[$2], $1, 1, '}'); # big room needs this fixup
        } elsif ($str =~ 


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
