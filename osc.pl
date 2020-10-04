#!/usr/bin/perl -w
use strict;
use lib ".";
use osc;

osc::init;
print osc::apiget(shift);
