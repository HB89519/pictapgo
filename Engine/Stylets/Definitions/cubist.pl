#!/usr/bin/perl -w

use strict;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

my $help = 0;
my %args;

GetOptions(\%args,
  'help|?' => \$help,
  'class|C=s', 'code|c=s', 'id|i=s', 'name|n=s',
  ) or pod2usage(2);
pod2usage(1) if $help;

unless (defined($args{class}) and defined($args{code}) and
  defined($args{id}) and defined($args{name})) {
    pod2usage(-message => 'All options are required', -exitval => 2);
}

my %list;
open LIST, "list";
while (<LIST>) {
    if (m/^(\S+)\s+([A-Za-z]+)/) {
        $list{$2} = $1;
    }
}
close LIST;

if (exists($list{$args{code}})) {
    die "The code $args{code} is already used in $list{$args{code}}\n";
}

while (<DATA>) {
    last if m/^__END__/;
    while ($_ =~ s/\$\{([^}]+)\}/$args{lc($1)}/) {}
    print $_;
}

__DATA__
#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface ${CLASS}_extras : NSObject {
@package
    TRCube* cube;
}
@end

@implementation ${CLASS}_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cube = [TRCube newWithInput:nil cubeFile:@"cube-${ID}" size:16];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"${CLASS}_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation ${CLASS}
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.${ID}"
      name:@"${NAME}" group:@"Clones" code:@"${CODE}"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    ${CLASS}_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[${CLASS}_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCube* cube = [extras->cube copy];
    cube.inputImage = input;
    return cube.outputImage;
}
@end

// ----------------------------------------------------------------------
// Add these lines in TRStylet.h
@interface ${CLASS} : TRStylet
@end

// ----------------------------------------------------------------------
// Add this line in TRStylet.mm
          [[${CLASS} alloc] init],

// ----------------------------------------------------------------------
// Add this line to the styletLibrary method in TRRecipe.mm
              @"${CODE}",

// ----------------------------------------------------------------------
// Add this line to the prepopulate method in Statistics/TRStatistics.m
      VAL(@"${NAME}", 0),              @"${CODE}",

// ----------------------------------------------------------------------
// Add this line to the list file
${CLASS}.mm         ${CODE}

__END__

=head1 NAME

cubist.pl - emit Objective-C code for a Stylet that uses a color cube

=head1 SYNOPSIS

cubist.pl --class ClassName --id id --code code --name "UI Name"

 Options:
   --class      Objective C class name
   --id         ID (in cube file of the form cube-ID.png)
   --code       "Atom" code for filter
   --name       name for filter shown in UI

=cut
