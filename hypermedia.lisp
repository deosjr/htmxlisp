#| https://hypermedia.systems/hypermedia-systems/ |#
(handlefunc "/" (lambda (w r) (httpwrite w "Hello World!")))

(handlefunc "/" (lambda (w r) (redirect w r "/contacts")))

(begin 

#| contacts mock db |#
(define contactdb (make-hashmap))
(define add-contact (lambda (firstname lastname phone email)
    (hashmap-set! contactdb (gensym) (let ((m (make-hashmap)))
        (hashmap-set! m "first" firstname)
        (hashmap-set! m "last"  lastname)
        (hashmap-set! m "phone" phone)
        (hashmap-set! m "email" email)
        m))))
(add-contact "Carson" "Gross" "123-456-7890" "carson@example.comz")
(add-contact "Carson" "Gross" "123-456-7890" "carson@example.comz")
(add-contact "Carson" "Gross" "123-456-7890" "carson@example.comz")

#| index.html template in multiple parts |#
(define layout "<!doctype html>
<html lang=''>
<head>
    <title>Contact App</title>
    <script src='https://unpkg.com/htmx.org@1.9.12/dist/htmx.min.js'></script>
</head>
<body hx-boost='true'>
<main>
    {{template \"content\" .}}
</main>
</body>
</html>")
(define content "{{define \"content\"}}<form action='/contacts' method='get' class='tool-bar'>
            <label for='search'>Search Term</label>
            <input id='search' type='search' name='q' value='{{.search}}'/>
            <input type='submit' value='Search'/>
     </form>
     {{template \"table\" .}}
     {{end}}")
(define table "{{define \"table\"}}
   <table>
        <thead>
        <tr>
            <th>First</th> <th>Last</th> <th>Phone</th> <th>Email</th> <th></th>
        </tr>
        </thead>
        <tbody>
        {{range .contacts}}
        <tr>
                <td>{{ (asmap .).first }}</td>
                <td>{{ (asmap .).last }}</td>
                <td>{{ (asmap .).phone }}</td>
                <td>{{ (asmap .).email }}</td>
                <td><a href='/contacts/{{ (asmap .).id }}/edit'>Edit</a>
                    <a href='/contacts/{{ (asmap .).id }}'>View</a></td>
            </tr>
        {{end}}
        </tbody>
    </table>
  {{end}}")
(define tmpl (template layout content table))

(handlefunc "/contacts" (lambda (w r) (render w tmpl `(("search" ,(formvalue r "q")) ("contacts" ,contactdb) ))))
)
