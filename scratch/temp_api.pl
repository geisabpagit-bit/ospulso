elsif ($action eq 'add_categoria') {
    my $nivel = $q->param('nivel') || '1';
    my $nombre = $q->param('nombre') || '';
    my $parent_id = $q->param('parent_id') || '';
    
    if (!$nombre) {
        print encode_json({ success => 0, message => 'Nombre requerido' });
        exit;
    }
    
    if ($nivel eq '1') {
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_cat.counter");
        my $l = "$nid|$nombre|";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/categorias.dat");
        print $f "$l\n";
        close $f;
    } elsif ($nivel eq '2') {
        if (!$parent_id) { print encode_json({ success=>0, message=>'Padre requerido' }); exit; }
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_subcat.counter");
        my $l = "$nid|$parent_id|$nombre|";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/sub_categoria.dat");
        print $f "$l\n";
        close $f;
    } elsif ($nivel eq '3') {
        if (!$parent_id) { print encode_json({ success=>0, message=>'Padre requerido' }); exit; }
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_subcat3.counter");
        my $l = "$nid|$parent_id|$nombre";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/sub_categoria_nivel3.dat");
        print $f "$l\n";
        close $f;
    }
    print encode_json({ success => 1 });
}
elsif ($action eq 'delete_categoria') {
    my $id = $q->param('id');
    my $nivel = $q->param('nivel');
    
    if (!$id || !$nivel) { print encode_json({ success=>0, message=>'ID o nivel faltante' }); exit; }
    
    # Validation against gastos
    my @gastos = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    for my $g (@gastos) {
        # g[2] is id_cat, g[3] is id_subcat, g[4] is id_subcat3
        if ($nivel eq '1' && $g->[2] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con esta categoría.' });
            exit;
        } elsif ($nivel eq '2' && $g->[3] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con esta subcategoría.' });
            exit;
        } elsif ($nivel eq '3' && $g->[4] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con este detalle.' });
            exit;
        }
    }
    
    # Do deletion
    my $file = "";
    if ($nivel eq '1') { $file = "categorias.dat"; }
    elsif ($nivel eq '2') { $file = "sub_categoria.dat"; }
    elsif ($nivel eq '3') { $file = "sub_categoria_nivel3.dat"; }
    
    my $path = "$FindBin::Bin/../dat/$file";
    my @lines;
    open(my $in, "<:encoding(UTF-8)", $path);
    while(<$in>) {
        my $line = $_;
        chomp($line);
        my @cols = split(/\|/, $line, -1);
        if ($cols[0] eq $id && $cols[0] ne 'id') { # Ensure not deleting header
            # Skip this line
        } else {
            push @lines, $line;
        }
    }
    close $in;
    
    open(my $out, ">:encoding(UTF-8)", $path);
    for my $l (@lines) {
        print $out "$l\n";
    }
    close $out;
    
    print encode_json({ success => 1 });
}
