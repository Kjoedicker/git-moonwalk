#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use experimental 'smartmatch';
use feature qw(switch);
use YAML qw(DumpFile LoadFile);
use Cwd qw(abs_path);

my $stashHistoryLocation = '/var/tmp/.stash_history_location.yml';

# **********************************
#   Reseting and stashing changes
# **********************************

sub gitExecute {
    my $command = shift;

    given($command) {

        when ('getTotalCommits') {
            chomp(my $totalCommits = `git rev-list HEAD --count`);

            return $totalCommits;
        }

        when ('getLatestCommitSubject') {
            chomp(my $subject = `git log -1 --pretty=\'\%s\'`);

            return $subject;
        }

        when ('getStashSubject') {
            chomp(my $subject = `git stash list -1 --pretty=\'\%s\'`);

            return $subject;
        }
      
        when ('stashChanges') {
            my ($commitSubject) = @_;

            my $command = "git stash push -m '$commitSubject' --include-untracked";

            return print `$command`;
        }

        when ('resetLatestCommit') {
            my $command = 'git reset --soft head~1'; 

            return print `$command`;
        }
    }
}

sub logStashedChanges {
    my (%stashedChanges) = @_;

    DumpFile($stashHistoryLocation, \%stashedChanges);
}

sub extractCommit {
    my ($totalSteps) = @_;
    my $step = $_;

    my $commitSubject = gitExecute('getLatestCommitSubject');

    # This is done backwards because of FIFO
    my $stashIndex = ($totalSteps - $step);

    print "Stash index: $stashIndex";

    gitExecute('resetLatestCommit');
    gitExecute('stashChanges', $commitSubject);

    return $stashIndex => $commitSubject ;
}

sub moonWalk {
    my ($totalSteps) = @_;

    my @steps = (1..$totalSteps);

    my %stashedChanges = ( stashIndexes => { map(extractCommit($totalSteps), @steps) } );

    logStashedChanges(%stashedChanges);
}

# **********************************
#     Re-Committing stashed changes
# **********************************

sub parseStashSubject {
    my $stashSubject = gitExecute('getStashSubject');
    
    # match everything after the colon 
    # except the first empty space
    my @commitSubject = $stashSubject =~ /:\s?(.*)/;

    return $commitSubject[0]   
}

sub recommitChanges {
    my ($index, $commitMessage) = @_;

    # git stash apply $index && 
    print `git stash pop && 
           git add . && 
           git commit -m '$commitMessage' --no-verify`;
}

sub cleanUpDataFile {
    unlink $stashHistoryLocation
}

sub applyStashedChanges {
    my $storedChanges = LoadFile($stashHistoryLocation)->{stashIndexes};
    
    my @keys = sort keys %$storedChanges;
    my $totalSize = (scalar @keys) - 1;
    
    for my $stashIndex (0..$totalSize) {
        my $messageKey = $keys[$stashIndex];

        my $commitMessage = parseStashSubject();

        recommitChanges($stashIndex, $commitMessage);    
    }

    cleanUpDataFile();
}

# **********************************
#     Initial Flow
# **********************************

sub validSteps {
    my ($steps) = @_;

    my $totalCommits = gitExecute('getTotalCommits');

    my $maxSteps = ($totalCommits - 1);

    return !($steps > $maxSteps);
}

sub parseArgs {
    my $error = 'Looks like there is nothing do here...';
    die $error if !(scalar @ARGV ~~ 1);
    
    ($_) = @ARGV;
}

# TODO: make these functions less dependent
sub start {
    parseArgs();

    if (!($_ eq '--restore')) {
        die "Cannot go beyond initial commit" unless validSteps($_);

        return moonWalk($_);
    }

    applyStashedChanges();
}

start();
