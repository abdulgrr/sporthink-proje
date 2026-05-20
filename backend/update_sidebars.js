const fs = require('fs');
const path = require('path');

const viewsDir = path.join(__dirname, 'views');
const files = fs.readdirSync(viewsDir).filter(f => f.endsWith('.ejs'));

const tipsLink = `<a href="/admin/tips" class="flex items-center px-4 py-3 text-slate-300 hover:bg-slate-800 rounded-lg transition-colors"><i class="fas fa-lightbulb w-6"></i> İpuçları (Tips)</a>`;

let updated = 0;
for (const file of files) {
    const filePath = path.join(viewsDir, file);
    let content = fs.readFileSync(filePath, 'utf8');

    // Skip if already has lightbulb link
    if (content.includes('fa-lightbulb')) {
        console.log(`SKIP (already has tips): ${file}`);
        continue;
    }

    // Insert tips link before the settings link
    if (content.includes('/admin/settings')) {
        content = content.replace(
            /(<a href="\/admin\/settings")/g,
            `${tipsLink}\n            $1`
        );
        fs.writeFileSync(filePath, content, 'utf8');
        updated++;
        console.log(`UPDATED: ${file}`);
    } else {
        console.log(`SKIP (no settings link): ${file}`);
    }
}
console.log(`\nDone. Updated ${updated} files.`);
