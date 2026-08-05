$_ = 'match this';
/match/;
print "Zero escaped: $'\n";
print "One escaped: \$\'\n";
print "Two escaped: \\$'\n";
print "Three escaped: \\\$'\n";
