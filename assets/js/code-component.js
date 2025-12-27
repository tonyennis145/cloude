import { html, render } from 'https://esm.sh/htm/preact/standalone';
import { monaco, loadCss } from 'https://esm.sh/monaco-esm';

// Load Monaco's CSS
loadCss();

MiniJS.register('monaco-editor', {
  editor: null,
  
  init() {
    this.paint();
  },
  
  paint() {
    const MonacoEditor = () => html`
      <div id="monaco-container" style="height: 600px; border: 1px solid #ccc;"></div>
    `;
    render(MonacoEditor(), this);
    
    // Initialize Monaco editor after DOM is ready
    setTimeout(() => {
      const container = this.querySelector('#monaco-container');
      if (container && !this.editor) {
        this.editor = monaco.editor.create(container, {
          value: '// Welcome to Monaco Editor!\nfunction hello() {\n  console.log("Hello, World!");\n}',
          language: 'javascript',
          theme: 'vs-dark',
          automaticLayout: true
        });
      }
    }, 0);
  },
  
  destroy() {
    if (this.editor) {
      this.editor.dispose();
      this.editor = null;
    }
  }
});

