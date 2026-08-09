use strict;
use warnings;
use File::Slurp;

my $file = 'views/crm_ventas.pl';
my $content = read_file($file);

# Separate the part before <script> and after
if ($content =~ /^(.*?<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/sweetalert2\\\@11"><\/script>\s*)(<script>.*<\/script>\s*)HTML(.*)$/s) {
    my $before = $1;
    my $script_block = $2;
    my $after = $3;
    
    # Close HTML heredoc and open JS heredoc
    $before .= "HTML\n\nprint <<'JS';\n";
    
    # Unescape \$ to $
    $script_block =~ s/\\\$/\$/g;
    
    # Close JS heredoc
    $script_block .= "JS\n";
    
    my $new_content = $before . $script_block . $after;
    write_file($file, $new_content);
    print "Refactored successfully\n";
} else {
    print "Could not match the structure\n";
}
