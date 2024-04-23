package main

import (
    "fmt"
    "html/template"
    "io"
    "net/http"
    "os"
    "strings"

    "github.com/google/uuid"

	"github.com/deosjr/whistle/lisp"
)

func gensym() string {
    return uuid.NewString()
}

var routingTable = map[string]string{}

func main() {
	l := lisp.New()

    l.Env.AddBuiltin("string:contains", func(args []lisp.SExpression) (lisp.SExpression, error) {
        s := args[0].AsPrimitive().(string)
        substr := args[1].AsPrimitive().(string)
        return lisp.NewPrimitive(strings.Contains(s, substr)), nil
    })

    l.Env.AddBuiltin("maplen", func(args []lisp.SExpression) (lisp.SExpression, error) {
        m := args[0].AsPrimitive().(map[lisp.SExpression]lisp.SExpression)
        return lisp.NewPrimitive(float64(len(m))), nil
    })

    l.Env.AddBuiltin("httpwrite", func(args []lisp.SExpression) (lisp.SExpression, error) {
        w := args[0].AsPrimitive().(http.ResponseWriter)
        s := args[1].AsPrimitive().(string)
        fmt.Fprint(w, s)
        return lisp.NewPrimitive(true), nil
    })

    l.Env.AddBuiltin("request:method", func(args []lisp.SExpression) (lisp.SExpression, error) {
        r := args[0].AsPrimitive().(*http.Request)
        return lisp.NewPrimitive(r.Method), nil
    })
    
    // TODO: path only checks prefix, use {$} to match exact path
    // TODO: path variables like /path/{var} and name clashes in routing table
    // (handlefunc "/path" (lambda () ...))
    // registers under gensym in routing table so we can redeclare
	l.Env.AddBuiltin("handlefunc", func(args []lisp.SExpression) (lisp.SExpression, error) {
        path := args[0].AsPrimitive().(string)
        fn := args[1].AsProcedure()
        s, ok := routingTable[path]
        if !ok {
            s = gensym()
            routingTable[path] = s
        }
        sym := lisp.NewSymbol(s)
        l.EvalExpr(lisp.MakeConsList([]lisp.SExpression{lisp.NewSymbol("define"), sym, fn}))

        if !ok {
            http.HandleFunc(path, func(w http.ResponseWriter, r *http.Request) {
                fn, err := l.EvalExpr(sym)
                if err != nil {
                    panic(err)
                }
                _, err = l.EvalExpr(lisp.MakeConsList([]lisp.SExpression{fn, lisp.NewPrimitive(w), lisp.NewPrimitive(r)}))
                if err != nil {
                    panic(err)
                }
            })
        }
		return lisp.NewPrimitive(true), nil
	})

    l.Env.AddBuiltin("redirect", func(args []lisp.SExpression) (lisp.SExpression, error) {
        w := args[0].AsPrimitive().(http.ResponseWriter)
        r := args[1].AsPrimitive().(*http.Request)
        path := args[2].AsPrimitive().(string)
        http.Redirect(w, r, path, 302)
        return lisp.NewPrimitive(true), nil
    })

    l.Env.AddBuiltin("formvalue", func(args []lisp.SExpression) (lisp.SExpression, error) {
        r := args[0].AsPrimitive().(*http.Request)
        key := args[1].AsPrimitive().(string)
        return lisp.NewPrimitive(r.FormValue(key)), nil
    })
    l.Env.AddBuiltin("pathvalue", func(args []lisp.SExpression) (lisp.SExpression, error) {
        r := args[0].AsPrimitive().(*http.Request)
        key := args[1].AsPrimitive().(string)
        return lisp.NewPrimitive(r.PathValue(key)), nil
    })

    l.Env.AddBuiltin("template", func(args []lisp.SExpression) (lisp.SExpression, error) {
        tmpls := []string{}
        for _, arg := range args {
            tmpls = append(tmpls, arg.AsPrimitive().(string))
        }
        fm := map[string]any{
            "str": func(e lisp.SExpression) string {
                if e == nil {
                    return ""
                }
                return e.AsPrimitive().(string)
            },
            "fromhashmap": func(e any) map[string]any { 
                ret := map[string]any{}
                switch t := e.(type) { 
                case lisp.SExpression:
                    m := t.AsPrimitive().(map[lisp.SExpression]lisp.SExpression)
                    for k, v := range m {
                        ret[k.AsPrimitive().(string)] = v
                    }
                case map[lisp.SExpression]lisp.SExpression:
                    for k, v := range t {
                        ret[k.AsPrimitive().(string)] = v
                    }
                }
                return ret
            },
            "lisp": func(funcname string, v ...lisp.SExpression) lisp.SExpression {
                e, err := l.EvalExpr(lisp.MakeConsList(append([]lisp.SExpression{lisp.NewSymbol(funcname)}, v...)))
                if err != nil {
                    panic(err)
                }
                return e
            },
        }
        t := template.Must(template.New("base").Funcs(fm).Parse(strings.Join(tmpls, "")))
        return lisp.NewPrimitive(t), nil
    })

    l.Env.AddBuiltin("render", func(args []lisp.SExpression) (lisp.SExpression, error) {
        w := args[0].AsPrimitive().(http.ResponseWriter)
        t := args[1].AsPrimitive().(*template.Template)
        m := map[string]any{}
        if args[2].IsPair() { // assume assoclist
            assoclist, err := lisp.UnpackConsList(args[2])
            if err != nil {
                panic(err)
            }
            for _, cons := range assoclist {
                c, err := lisp.UnpackConsList(cons)
                if err != nil {
                    panic(err)
                }
                if len(c) != 2 {
                    panic("not a cons cell")
                }
                m[c[0].AsPrimitive().(string)] = c[1].AsPrimitive()
            }
        } else {
            switch t := args[2].AsPrimitive().(type) {
            case map[lisp.SExpression]lisp.SExpression:
                for k, v := range t {
                    m[k.AsPrimitive().(string)] = v
                }
            case map[string]string:
                for k, v := range t {
                    m[k] = v
                }
            }
        }
        if err := t.Execute(w, m); err != nil {
            panic(err)
        }
        return lisp.NewPrimitive(true), nil
    })

    l.Eval(`(handlefunc "/" (lambda (w r) (httpwrite w "<h1>HELLO</h1>")))`)

    os.Truncate("eval.log", 0)
    evallog, err := os.OpenFile("eval.log", os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		panic(err)
	}
    defer evallog.Close()

    // not going via handlefunc means it cannot be redeclared!
    http.HandleFunc("/eval", func(w http.ResponseWriter, r *http.Request) {
        s, err := io.ReadAll(r.Body)
        if err != nil {
            fmt.Fprintf(w, "%s", err)
            return
        }
        evallog.Write([]byte(fmt.Sprintf("%s\n", s)))
        e, err := l.Eval(string(s))
        if err != nil {
            fmt.Fprintf(w, "%s", err)
            return
        }
        fmt.Fprintf(w, "%s", e)
    })

    l.Env.AddBuiltin("routingtable", func(args []lisp.SExpression) (lisp.SExpression, error) {
        m := map[string]string{}
        for path, sym := range routingTable {
            fn, err := l.EvalExpr(lisp.NewSymbol(sym))
            if err != nil {
                panic(err)
            }
            s, err := l.EvalExpr(lisp.MakeConsList([]lisp.SExpression{lisp.NewSymbol("proc->string"), fn}))
            if err != nil {
                panic(err)
            }
            m[path] = s.AsPrimitive().(string)
        }
        return lisp.NewPrimitive(m), nil
    })

    go http.ListenAndServe(":8080", nil)

    if err := evalFromFile(l, "hypermedia.lisp"); err != nil {
        panic(err)
    }
    if err := evalFromFile(l, "admin.lisp"); err != nil {
        panic(err)
    }

    // wait forever, http server is spinning
    for {}
}

// TODO toggle step-through or eval everything
func evalFromFile(l lisp.Lisp, filename string) error {
    sexprs, err := lisp.ParseFile(filename)
    if err != nil {
        return err
    }
    for _, ex := range sexprs {
        _, err := l.EvalExpr(ex)
        if err != nil {
            return err
        }
    }
    return nil
}
