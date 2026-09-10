my $dat_dir='dat'; my $id_empresa='1'; my $org_clues=''; 
open(my $nf, '<:utf8', 'dat/negocios.dat'); 
while(<$nf>){ 
    chomp; 
    my @f=split(/\|/,$_,-1); 
    if($f[0] eq $id_empresa){
        $org_clues=$f[18]//''; 
        last;
    } 
} 
print "CLUE: $org_clues\n";
require File::Spec->catfile('utils', 'catalogo_org_utils.pl');
my $rutas = catalogo_org_utils::obtener_rutas_por_clue($org_clues);
print "Motivos file: ", $rutas->{motivos}, "\n";
print "File exists: ", (-e $rutas->{motivos} ? "yes" : "no"), "\n";
