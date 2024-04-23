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
