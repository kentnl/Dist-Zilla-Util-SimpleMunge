use strict;
use warnings;

package Dist::Zilla::Util::SimpleMunge;

# ABSTRACT: Make munging File::FromCode and File::InMemory easier.

use Moose;

=head1 SYNOPSIS

  use Dist::Zilla::Util::SimpleMunge qw( munge_file munge_files );
  ...;

  sub somesub {
    ...;
    munge_file $file_from_zilla, {
      via => sub {
        my ( $file, $content ) = @_;
        ... mangle $content here ...;
        return $mangled;
      },
    };
  }

=cut

=func munge_file

  # munge_file ( $FILE , \%CONFIGURATION )

  munge_file(
    $zilla_file,
    {
      via => sub { ... },
        lazy => $laziness
    }
  );

=head4 $FILE

A L<Dist::Zilla::Role::File> object to munge.

=head4 %CONFIGURATION

  {
    via => $CODEREF,
    lazy => $LAZINESS,
  }

=head4 $CODEREF

Called to munge the file itself.

Passed a reference to the L<Dist::Zilla::Role::File> instance, and a scalar containing
the contents of that file.

Return new content for the file via C<return>

  sub {
    my ( $file, $content ) = @_ ;
    ...;
    return $newcontent;
  }

=head4 $LAZINESS

Specify how lazy you want the munge to be performed. Normally, what this is set to is dependent on the type of file
being munged.

  $LAZINESS = undef ;  # use default for the file type
  $LAZINESS = 0     ;  # Munge immediately
  $LAZINESS = 1     ;  # Defer munging till as late as possible.

For things that are normally backed by scalar values, such as L<Dist::Zilla::File::OnDisk> and
L<Dist::Zilla::File::InMemory>, the laziness is equivalent to C< $LAZINESS = 0 >, which is not lazy at all, and
munges the file content immediately.

For things backed by code, such as L<Dist::Zilla::File::FromCode>, munging defaults to C< $LAZINESS = 1 >, where the
actual munging sub you specify is executed as late as possible.

You can specify the C< $LAZINESS > value explicitly if you want to customize the behaviour, ie: Make something that
is presently a scalar type get munged as late as possible ( converting the file into a C<FromCode> file ), or make
something currently backed by code get munged "now", ( converting the file into a C<InMemory> file )

=func munge_files

This is mostly a convenience utility for munging a lot of files without having to hand-code the looping logic.

It basically just proxies for L</munge_file>.

  # munge_files ( \@FILEARRAY , \%CONFIGURATION )

  munge_files( [ $zilla_file_one, $zilla_file_two, ], {
    via => sub { ... },
    lazy => $laziness,
  });

=head4 @FILEARRAY

An C<ArrayRef> of L</$FILE>

=head4 See Also

=over 4

=item * L</%CONFIGURATION>

=item * L</$CODEREF>

=item * L</$FILE>

=item * L</$LAZINESS>

=back

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;
