const fs = require('fs');
const html = fs.readFileSync('output.html', 'utf8');
const regex = /<script.*?>([\s\S]*?)<\/script>/gi;
let match;
let i = 0;
while ((match = regex.exec(html)) !== null) {
    fs.writeFileSync('script_' + i + '.js', match[1]);
    try {
        require('child_process').execSync('node -c script_' + i + '.js', {stdio: 'inherit'});
        console.log('Script ' + i + ' OK');
    } catch (e) {
        console.log('Script ' + i + ' FAIL');
    }
    i++;
}
