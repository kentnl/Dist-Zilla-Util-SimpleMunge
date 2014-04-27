use strict;
use warnings;

package Dist::Zilla::Util::SimpleMunge;
$Dist::Zilla::Util::SimpleMunge::VERSION = '0.002003';
# ABSTRACT: Make munging File::FromCode and File::InMemory easier.

use Sub::Exporter -setup => { exports => [qw[ munge_file munge_files ]], };















































































sub _fromcode_munge {
  my ( $file, $config ) = @_;
  if ( defined $config->{lazy} and $config->{lazy} == 0 ) {

    # This is a little bit nasty, but can you suggest a better way?
    # TODO
    my $content = $file->content();
    delete $file->{code};
    require Dist::Zilla::File::InMemory;
    bless $file, 'Dist::Zilla::File::InMemory';
    $file->content( $config->{via}->( $file, $content ) );
    return 1;
  }
  my $coderef = $file->code();
  $file->code(
    sub {
      return $config->{via}->( $file, $coderef->($file) );
    }
  );
  return 1;
}

sub _scalar_munge {
  my ( $file, $config ) = @_;
  if ( defined $config->{lazy} and $config->{lazy} == 1 ) {

    # This is a little bit nasty, but can you suggest a better way?
    # TODO
    my $content = delete $file->{content};
    require Dist::Zilla::File::FromCode;
    bless $file, 'Dist::Zilla::File::FromCode';
    $file->code(
      sub {
        return $config->{via}->( $file, $content );
      }
    );
    return 1;
  }
  $file->content( $config->{via}->( $file, $file->content ) );
  return 1;
}

sub munge_file {
  my (@all) = @_;
  my ( $file, $config, @rest ) = @all;

  if (@rest) {
    __PACKAGE__->_error(
      ## no critic (RequireInterpolationOfMetachars)
      message => q[munge_file only accepts 2 parameters, $FILE and \%CONFIG],
      payload => {
        parameters => \@all,
        errors     => \@rest,
        understood => {
          qw( $file )   => $file,
          qw( $config ) => $config,
        },
      },
      tags => [qw( parameters excess munge_file )],
      id   => 'munge_file_params_excess',
    );
  }

  if ( not $file or not $file->can('content') ) {
    __PACKAGE__->_error(
      message => 'munge_file must be passed a Dist::Zilla File or a compatible object for parameter 0',
      payload => {
        parameter_no => 0,
        expects      => [qw[ defined ->can(content) ]],
        got          => $file,
      },
      id   => 'munge_file_param_file_bad',
      tags => [qw( parameters file bad mismatch invalid )],
    );
  }

  if ( not ref $config or not ref $config eq 'HASH' ) {
    __PACKAGE__->_error(
      message => 'munge_file must be passed a HashReference for parameter 1',
      payload => {
        parameter_no => 1,
        expects      => [qw[ defined ref Hash ]],
        got          => $file,
      },
      id   => 'munge_file_param_config_bad',
      tags => [qw( parameters config bad mismatch invalid )],
    );
  }

  if ( not exists $config->{via} or not defined $config->{via} or not ref $config->{via} eq 'CODE' ) {
    __PACKAGE__->_error(
      message => 'munge_file must be passed a subroutine in the configuration hash as \'via\'',
      payload => {
        parameter_name => 'via',
        expects        => [qw[ exists defined ref Code ]],
        got            => $config->{via},
      },
      id   => 'munge_file_config_via_bad',
      tags => [qw( parameters config via bad mismatch invalid )],
    );
  }

  if (
    exists $config->{lazy}
    and not( ( not defined $config->{lazy} )
      or ( $config->{lazy} == 0 )
      or ( $config->{lazy} == 1 ) )
    )
  {
    __PACKAGE__->_error(
      message => 'munge_file configuration value \'lazy\' must be un-set, undef, 0 or 1',
      payload => {
        parameter_name => 'lazy',
        expects_one    => [qw[ unset undef 0 1 ]],
        got            => $config->{lazy},
      },
      id   => 'munge_file_config_lazy_bad',
      tags => [qw( parameters config lazy bad mismatch invalid )],
    );
  }

  # This codeblock exists for permitting one or more forms of "native" munging.
  # Presently undocumented as the underlying support is still non-existent.
  #
  # There is only presently one supported option
  #    { native => "filemungeapi" }
  # which will call the ->munge method on the file instance
  # using the form currently defined by this pull request:
  #
  #   https://github.com/rjbs/dist-zilla/pull/24
  #
  # This allows for per-file custom class methods for defining exactly how munge is performed
  # but presently lacks passing arbitrary munge control flags ( ie: forced lazy etc )
  #
  # If it doesn't look like the file in question conforms to the requested munge api,
  # then it falls back to traditional dzil.
  #
  # An object with a ->code method is assumed to be from code,
  #
  # and everything else is assumed to be in-memory scalars.
  #
  if ( exists $config->{native} and defined $config->{native} ) {
    if ( $config->{native} eq 'filemungeapi' ) {    # The API as proposed by Kentnl
      if ( $file->can('munge') ) {
        return $file->munge( $config->{via} );
      }
    }
  }
  if ( $file->can('code') ) {
    return _fromcode_munge( $file, $config );
  }
  return _scalar_munge( $file, $config );
}


































sub munge_files {
  my ( $array, $config ) = @_;
  for my $file ( @{$array} ) {
    return unless munge_file( $file, $config );
  }
  return 1;
}

sub _error {
  my ( $self, %config ) = @_;
  require Carp;
  return Carp::croak( $config{message} );
}

1;

__END__

=pod

=head1 NAME

Dist::Zilla::Util::SimpleMunge - Make munging File::FromCode and File::InMemory easier.

=head1 VERSION

version 0.002003

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

=head1 FUNCTIONS

=head2 munge_file

  # munge_file ( $FILE , \%CONFIGURATION )

  munge_file(
    $zilla_file,
    {
      via => sub { ... },
        lazy => $laziness
    }
  );

=head4 $FILE

A L<< C<::Role::File> |Dist::Zilla::Role::File >> object to munge.

=head4 %CONFIGURATION

  {
    via => $CODEREF,
    lazy => $LAZINESS,
  }

=head4 $CODEREF

Called to munge the file itself.

Passed a reference to the L<< C<::Role::File> |Dist::Zilla::Role::File >> instance, and a scalar containing
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

For things that are normally backed by scalar values, such as L<< C<::File::OnDisk> |Dist::Zilla::File::OnDisk >> and
L<< C<::File::InMemory> |Dist::Zilla::File::InMemory >>, the laziness is equivalent to C< $LAZINESS = 0 >, which is not lazy at all, and
munges the file content immediately.

For things backed by code, such as L<< C<::File::FromCode> |Dist::Zilla::File::FromCode >>, munging defaults to C< $LAZINESS = 1 >, where the
actual munging sub you specify is executed as late as possible.

You can specify the C< $LAZINESS > value explicitly if you want to customize the behaviour, i.e.: Make something that
is presently a scalar type get munged as late as possible ( converting the file into a C<FromCode> file ), or make
something currently backed by code get munged "now", ( converting the file into a C<InMemory> file )

=head2 munge_files

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

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
