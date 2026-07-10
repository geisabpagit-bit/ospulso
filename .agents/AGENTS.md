
- Al terminar modificaciones, siempre realizar 'git add .', 'git commit' y 'git push' automaticamente.
- IMPORTANTE: Al crear o editar scripts .pl, si se inyecta CSS o Javascript dentro de bloques interpolados (como prints con comillas dobles o heredocs `<<"HTML"`), se deben escapar símbolos de arroba como `\@media` para evitar el error de compilación "Global symbol requires explicit package name".
