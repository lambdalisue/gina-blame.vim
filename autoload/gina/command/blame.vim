let s:Anchor = vital#gina#import('Vim.Buffer.Anchor')
let s:Observer = vital#gina#import('Vim.Buffer.Observer')
let s:Path = vital#gina#import('System.Filepath')
let s:String = vital#gina#import('Data.String')
let s:SCHEME = gina#command#scheme(expand('<sfile>'))


function! gina#command#blame#call(range, args, mods) abort
  let git = gina#core#get_or_fail()
  let args = s:build_args(git, a:args)
  let pipe = gina#command#blame#pipe#parser()
  let job = gina#process#open(git, args, pipe)
  let status = job.wait()
  let blame = {
        \ 'args': job.args,
        \ 'status': status,
        \ 'content': pipe._stderr,
        \ 'revisions': job.revisions,
        \ 'chunks': job.chunks,
        \}
  if blame.status
    throw gina#process#error(blame)
  endif
  let show = gina#process#call(git, [
        \ 'show', printf('%s:%s', args.params.revision, args.params.relpath)
        \])
  if show.status
    throw gina#process#error(show)
  endif


  let body_bufname = gina#core#buffer#bufname(git, 'blame', {
        \ 'revision': args.params.revision,
        \ 'relpath': args.params.relpath,
        \ 'params': ['body']
        \})
  call gina#core#buffer#open(body_bufname, {
        \ 'mods': a:mods,
        \ 'group': args.params.group,
        \ 'opener': args.params.opener,
        \ 'cmdarg': args.params.cmdarg,
        \ 'callback': {
        \   'fn': function('s:init'),
        \   'args': [args],
        \ }
        \})
  setlocal scrollbind
  setlocal filetype=gina-blame-body
  call s:define_highlights()
  let navi_bufname = gina#core#buffer#bufname(git, 'blame', {
        \ 'revision': args.params.revision,
        \ 'relpath': args.params.relpath,
        \ 'params': ['navi']
        \})
  call gina#core#buffer#open(navi_bufname, {
        \ 'mods': 'topleft',
        \ 'group': '',
        \ 'opener': args.params.width . 'vsplit',
        \ 'cmdarg': args.params.cmdarg,
        \ 'callback': {
        \   'fn': function('s:init'),
        \   'args': [args],
        \ }
        \})
  setlocal scrollbind
  setlocal filetype=gina-blame-navi
  call s:define_highlights()
  call gina#util#syncbind()

  let formatter = gina#command#blame#formatter#new(
        \ winwidth(0),
        \ show.content,
        \ blame.revisions,
        \)
  call s:assign_content(
        \ bufnr(navi_bufname),
        \ bufnr(body_bufname),
        \ formatter,
        \ blame.chunks,
        \)
endfunction


" Private --------------------------------------------------------------------
function! s:build_args(git, args) abort
  let args = gina#command#parse_args(a:args)
  let args.params.group = args.pop('--group', '')
  let args.params.opener = args.pop('--opener', 'tabedit')
  let args.params.width = args.pop('--width', 50)
  let args.params.line = args.pop('--line', v:null)
  let args.params.col = args.pop('--col', v:null)

  let args.params.revision = args.pop(1, gina#core#buffer#param('%', 'revision'))
  let args.params.abspath = gina#core#path#abspath(get(args.residual(), 0, '%'))
  let args.params.relpath = gina#core#repo#relpath(a:git, args.params.abspath)

  call args.pop('--porcelain')
  call args.pop('--line-porcelain')
  call args.set('--incremental', 1)
  call args.set(1, args.params.revision)
  call args.residual([args.params.abspath])
  return args.lock()
endfunction

function! s:init(args) abort
  call gina#core#meta#set('args', a:args)

  if exists('b:gina_initialized')
    return
  endif
  let b:gina_initialized = 1

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  "setlocal nomodifiable
  setlocal nobuflisted
  setlocal winfixheight
  setlocal nolist nospell
  setlocal nowrap nofoldenable
  setlocal nonumber norelativenumber
  setlocal foldcolumn=0 colorcolumn=0

  " Attach modules
  call s:Anchor.attach()
  call s:Observer.attach()
  call gina#action#attach(function('s:get_candidates'))
  call gina#action#include('browse')
  call gina#action#include('info')
  call gina#action#include('show')

  augroup gina_internal_command
    autocmd! * <buffer>
    autocmd ColorScheme <buffer> call s:define_highlights()
  augroup END
endfunction

function! s:assign_content(navi_bufnr, body_bufnr, formatter, chunks) abort
  call s:define_highlights()
  call setbufvar(a:navi_bufnr, 'gina_chunks', a:chunks)
  call setbufvar(a:body_bufnr, 'gina_chunks', a:chunks)
  execute printf('sign unplace * buffer=%d', a:navi_bufnr)
  execute printf('sign unplace * buffer=%d', a:body_bufnr)
  let linenum = 0
  execute printf(
        \ 'sign place 1 line=1 name=GinaPseudoEmptySign buffer=%d',
        \ a:navi_bufnr,
        \)
  execute printf(
        \ 'sign place 1 line=1 name=GinaPseudoEmptySign buffer=%d',
        \ a:body_bufnr,
        \)
  for chunk in a:chunks
    let formatted = a:formatter.format(chunk)
    call gina#core#writer#extend_content(a:navi_bufnr, formatted.navi)
    call gina#core#writer#extend_content(a:body_bufnr, formatted.body)
    let linenum += len(formatted.navi)
    execute printf(
          \ 'sign place %d line=%d name=GinaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, a:navi_bufnr,
          \)
    execute printf(
          \ 'sign place %d line=%d name=GinaPseudoSeparatorSign buffer=%d',
          \ linenum, linenum, a:body_bufnr,
          \)
    sleep 10m
  endfor
  call s:define_highlights()
endfunction

function! s:get_candidates(fline, lline) abort
  return []
endfunction

function! s:define_highlights() abort
  highlight GinaPseudoSeparatorDefault term=underline cterm=underline ctermfg=242 gui=underline guifg=#36363
  highlight default link GinaPseudoSeparator GinaPseudoSeparatorDefault
  sign define GinaPseudoSeparatorSign texthl=SignColumn linehl=GinaPseudoSeparator
  sign define GinaPseudoEmptySign
endfunction

call s:define_highlights()

call gina#config(expand('<sfile>'), {
      \ 'use_default_aliases': 1,
      \ 'use_default_mappings': 1,
      \})
