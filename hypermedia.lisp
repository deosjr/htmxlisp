#| https://hypermedia.systems/hypermedia-systems/ |#
(handlefunc "/" (lambda (w r) (httpwrite w "Hello World!")))

(handlefunc "/" (lambda (w r) (redirect w r "/contacts")))

(begin 

#| contacts mock db |#
(define contactdb (make-hashmap))
(define make-contact (lambda (firstname lastname phone email)
    (let ((m (make-hashmap)))
        (hashmap-set! m "first" firstname)
        (hashmap-set! m "last"  lastname)
        (hashmap-set! m "phone" phone)
        (hashmap-set! m "email" email)
        m)))
(define empty-contact (lambda () (make-contact "" "" "" "")))
(define validate-contact (lambda (c)
    (let ((email (hashmap-ref c "email" "")))
        (if (eqv? email "") (begin (hashmap-set! c "errors" "Email Required") #f)
        #| yes this is false positive if name/phone includes email, but whatever.. |#
        (if (not (= 0 (maplen (search-contacts email)))) (begin (hashmap-set! c "errors" "Email Must Be Unique") #f)
        #t)))))

(define save-contact (lambda (c)
    (if (not (validate-contact c)) #f
    (let ((id (number->string (+ (maplen contactdb) 1))))
        (hashmap-set! c "id" id)
        (hashmap-set! contactdb id c)
        #t))))
(define add-contact (lambda (firstname lastname phone email)
    (save-contact (make-contact firstname lastname phone email))))

(define search-contacts (lambda (q) (begin
    (define match-contact (lambda (c q)
        (if (string:contains (hashmap-ref c "first" "") q) #t
        (if (string:contains (hashmap-ref c "last" "")  q) #t
        (if (string:contains (hashmap-ref c "phone" "") q) #t
        (if (string:contains (hashmap-ref c "email" "") q) #t
        #f))))))
    (define loop-and-search (lambda (m keys)
        (if (not (null? keys)) (let ((c (hashmap-ref contactdb (car keys) #f)))
          (if (match-contact c q) (hashmap-set! m (car keys) c))
          (loop-and-search m (cdr keys))
        ))))
    (let ((m (make-hashmap)))
      (loop-and-search m (hashmap-keys contactdb))
    m))))

(add-contact "John" "Smith" "123-456-7890" "john@example.comz")
(add-contact "Dana" "Crandith" "123-456-7890" "dcran@example.com")
(add-contact "Edith" "Neutvaar" "123-456-7890" "en@example.com")

#| index.html template in multiple parts |#
(define layout "<!doctype html>
<html lang=''>
<head>
    <title>Contact App</title>
    <script src='https://unpkg.com/htmx.org@1.9.12/dist/htmx.min.js'></script>
    <link rel='stylesheet' href='https://unpkg.com/missing.css@0.2.0/missing.min.css'>
    <style>td { vertical-align: middle; }</style>
    <style>table { width: 100%; margin-bottom: 12px; }</style>
</head>
<body hx-boost='true'>
<main>
    <header>
        <h1>
            <h>CONTACTS.APP</h>
            <sub-title>A Demo Contacts Application</sub-title>
        </h1>
    </header>
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
     <p>
        <a href='/contacts/new'>Add Contact</a>
    </p>
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
        {{with fromhashmap .}}
        <tr>
                <td>{{str .first }}</td>
                <td>{{str .last }}</td>
                <td>{{str .phone }}</td>
                <td>{{str .email }}</td>
                <td><a href='/contacts/{{str .id }}/edit'>Edit</a>
                    <a href='/contacts/{{str .id }}'>View</a></td>
            </tr>
        {{end}}
        {{end}}
        </tbody>
    </table>
  {{end}}")
(define tmpl (template layout content table))

(handlefunc "/contacts" (lambda (w r)
                          (let ((q (formvalue r "q")))
                            (render w tmpl `(("search" ,q) ("contacts" ,(search-contacts q)) )))))
)

(begin
(define input (lambda (form lower upper)
    (string-append
        "<label for='" form "'>" upper "</label>
        <input name='" lower "' id='" lower "' type='text' placeholder='" upper "' value='{{ str ." lower " }}'>")))
(define newcontent (string-append "{{define \"content\"}}
<form action='/contacts/new' method='post'>
    <fieldset>
        <legend>Contact Values</legend>
        <div class='table rows'>
            <p>"
            (input "email" "email" "Email")
            "<span class='error'>{{ str .errors }}</span>
            </p>
            <p>"
            (input "first_name" "first" "First Name")
            "</p>
            <p>"
            (input "last_name" "last" "Last Name")
            "</p>
            <p>"
            (input "phone" "phone" "Phone")
            "</p>
        </div>
        <button>Save</button>
    </fieldset>
</form>

<p>
    <a href='/contacts'>Back</a>
</p>{{end}}"))
(define newtmpl (template layout newcontent))
(handlefunc "/contacts/new" (lambda (w r) (render w newtmpl (empty-contact))))
)

(begin
(define handle-post-new (lambda (w r)
    (let ((c (make-contact (formvalue r "first_name") (formvalue r "last_name") (formvalue r "phone") (formvalue r "email"))))
      (if (save-contact c)
        #| we're going to ignore flash messages for now |#
        (redirect w r "/contacts")
        (render w newtmpl c)
      ))))

(handlefunc "/contacts/new" (lambda (w r)
    (if (eqv? (request:method r) "GET") (render w newtmpl (empty-contact))
    (if (eqv? (request:method r) "POST") (handle-post-new w r)))))
)

(begin
(define showtmpl (template layout "{{define \"content\"}}
<h1>{{str .first}} {{str .last}}</h1>
<div>
    <div>Phone: {{str .phone}}</div>
    <div>Email: {{str .email}}</div>
</div>
<p>
    <a href='/contacts/{{str .id}}/edit'>Edit</a>
    <a href='/contacts'>Back</a>
</p>{{end}}"))
(handlefunc "/contacts/{id}" (lambda (w r)
    (render w showtmpl (hashmap-ref contactdb (pathvalue r "id") (empty-contact)))))
)

(begin
(define edittmpl (template layout "{{define \"content\"}}
<form action='/contacts/{{ str .id }}/edit' method='post'>
    <fieldset>
        <legend>Contact Values</legend>
        <div class='table rows'>
            <p>
                <label for='email'>Email</label>
                <input name='email' id='email' type='text' placeholder='Email' value='{{ str .email }}'>
                <span class='error'>{{ str .errors }}</span>
            </p>
            <p>
                <label for='first_name'>First Name</label>
                <input name='first_name' id='first_name' type='text' placeholder='First Name' value='{{ str .first }}'>
            </p>
            <p>
                <label for='last_name'>Last Name</label>
                <input name='last_name' id='last_name' type='text' placeholder='Last Name' value='{{ str .last }}'>
            </p>
            <p>
                <label for='phone'>Phone</label>
                <input name='phone' id='phone' type='text' placeholder='Phone' value='{{ str .phone }}'>
            </p>
        </div>
        <button>Save</button>
    </fieldset>
</form>
<form action='/contacts/{{ str .id }}/delete' method='post'>
    <button>Delete Contact</button>
</form>

<p>
    <a href='/contacts/'>Back</a>
</p>
{{end}}"))
(define handle-post-edit (lambda (w r)
    (let ((c (make-contact (formvalue r "first_name") (formvalue r "last_name") (formvalue r "phone") (formvalue r "email"))))
      #| TODO: update-contact |#
      (if (save-contact c)
        #| we're going to ignore flash messages for now |#
        (redirect w r (string-append "/contacts/" (pathvalue r "id")))
        (render w edittmpl c)
      ))))
(handlefunc "/contacts/{id}/edit" (lambda (w r)
    (if (eqv? (request:method r) "GET") (render w edittmpl (hashmap-ref contactdb (pathvalue r "id") (empty-contact)))
    (if (eqv? (request:method r) "POST") (handle-post-edit w r)))))
)

#| TODO: delete-contact |#
(handlefunc "/contacts/{id}/delete" (lambda (w r)
    (if (eqv? (request:method r) "POST") (redirect w r "/contacts"))))
