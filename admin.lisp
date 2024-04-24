#| admin page to interact with http server while it is running |#
(begin
(define adminlayout "<!doctype html>
<html lang=''>
<head>
    <title>Admin</title>
    <script src='https://unpkg.com/htmx.org@1.9.12/dist/htmx.min.js'></script>
    <link rel='stylesheet' href='https://unpkg.com/missing.css@0.2.0/missing.min.css'>
    <style>td { vertical-align: middle; }</style>
    <style>table { width: 100%; margin-bottom: 12px; }</style>
</head>
<body hx-boost='true'>
<main>
    <header>
        <h1>
            <h>ADMIN</h>
            <sub-title>Modify your HTTP server</sub-title>
        </h1>
    </header>
    {{template \"content\" .}}
</main>
</body>
</html>")
(define admincontent "{{define \"content\"}}
     {{template \"table\" .}}
     <p>
        <a href='/admin/new'>Add Endpoint</a>
    </p>
     {{end}}")
(define admintable "{{define \"table\"}}
   <table>
        <thead>
        <tr>
            <th>Path</th> <th>Implementation</th><th></th>
        </tr>
        </thead>
        <tbody>
        {{range $path, $value := .}}
        <tr>
                <td>{{ $path }}</td>
                <td>{{ $value }}</td>
                <td><a href='/admin{{ $path }}/edit'>Edit</a>
                    <a href='/admin{{ $path }}'>View</a></td>
            </tr>
        {{end}}
        </tbody>
    </table>
  {{end}}")
(define admintmpl (template adminlayout admincontent admintable))

(handlefunc "/admin" (lambda (w r) (render w admintmpl (routingtable))))
)

(begin
(define newadmin (string-append "{{define \"content\"}}
<div>
    <p>
     <input name='path' id='path' type='text' placeholder='Path' value='{{ str .path }}'>
    <span class='error'>{{ str .patherr }}</span>
    </p>
    <p>
    <div id=editor></div>
    <span class='error'>{{ str .codeerr }}</span>
    </p>
    <input name='output' id='output' type='text'>
    <button hx-post='/admin/new' hx-include='#path,#output' hx-target='main'>Save</button>
</div>

<p>
    <a href='/admin'>Back</a>
</p>
<style>
#output {
    display: none;
}
.codeflask.codeflask--has-line-numbers {
    left: 200px;
}
.codeflask.codeflask--has-line-numbers:before {
    background: var(--gray-12); // from missing.min.css
}
/*
.codeflask .token.keyword {
    color: purple;
}
.codeflask .token.string {
    color: brown;
}
*/
</style>
<script type='module'>
import CodeFlask from 'https://cdn.jsdelivr.net/npm/codeflask@1.4.1/+esm';
import Prism from 'https://cdn.jsdelivr.net/npm/prismjs@1.29.0/+esm';
//import 'https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-lisp.min.js' 

const editor = document.getElementById('editor');
const output = document.getElementById('output');

const prismGrammarLisp = {
  string: {
    pattern: /\"(\\\"|[^\"])+\"/,
    greedy: true,
  },
  paren: {
    pattern: /[()]/,
    alias: 'punctuation',
  },
  builtin: {
    pattern: /\b(lambda|define|if|let)\b/,
    alias: 'keyword',
  },
  symbol: {
    pattern: /[^ ]+/,
  },
};

const flask = new CodeFlask(editor, {
    language: 'lisp',
    lineNumbers: true,
    defaultTheme: false
});
flask.addLanguage('lisp', prismGrammarLisp);

flask.onUpdate( e => {
    output.value = e
})

// disable Prism autohighlighting on load
window.Prism = window.Prism || {};
Prism.manual = true;

flask.updateCode(`(lambda (w r) \"implement me\")`)
console.log(flask.getCode())
</script>

{{end}}"))
(define newadmintmpl (template adminlayout newadmin))
(handlefunc "/admin/new" (lambda (w r)
    (if (eqv? (request:method r) "GET") (render w newadmintmpl (make-hashmap))
    (if (eqv? (request:method r) "POST")
      (begin
        (handlefunc (formvalue r "path") (eval (read-string (formvalue r "output"))))
        (redirect w r "/admin" ))))))
)
