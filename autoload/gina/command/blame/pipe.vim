let s:IDENTIFIERS = [
      \ ['author-mail', len('author-mail'), 'author_mail'],
      \ ['author-time', len('author-time'), 'author_time'],
      \ ['author-tz', len('author-tz'), 'author_tz'],
      \ ['author', len('author'), 'author'],
      \ ['committer-mail', len('committer-mail'), 'committer_mail'],
      \ ['committer-time', len('committer-time'), 'committer_time'],
      \ ['committer-tz', len('committer-tz'), 'committer_tz'],
      \ ['committer', len('committer'), 'committer'],
      \ ['summary', len('summary'), 'summary'],
      \ ['previous', len('previous'), 'previous'],
      \ ['filename', len('filename'), 'filename'],
      \ ['boundary', len('boundary'), 'boundary'],
      \]

function! gina#command#blame#pipe#parser() abort
  let parser_pipe = copy(s:parser_pipe)
  let parser_pipe.revisions = {}
  let parser_pipe.chunks = []
  let parser_pipe._stderr = []
  let parser_pipe._chunk = {}
  let parser_pipe._previous = ''
  return parser_pipe
endfunction


" Parser pipe ----------------------------------------------------------------
let s:parser_pipe = {}

function! s:parser_pipe.on_stdout(job, msg, event) abort
  let content = [self._previous . get(a:msg, 0, '')] + a:msg[1:-1]
  let self._previous = a:msg[-1]
  for record in filter(content, '!empty(v:val)')
    call self.parse(record)
  endfor
endfunction

function! s:parser_pipe.on_stderr(job, msg, event) abort
  let leading = get(self._stderr, -1, '')
  if len(self._stderr) > 0
    call remove(self._stderr, -1)
  endif
  call extend(self._stderr, [leading . get(a:msg, 0, '')] + a:msg[1:])
endfunction

function! s:parser_pipe.on_exit(job, msg, event) abort
  if a:msg == 0
    if !empty(self._previous)
      call self.parse(self._previous)
    endif
    call sort(self.chunks, function('s:compare_chunks'))
    call map(self.chunks, 'extend(v:val, {''index'': v:key})')
  endif
  call gina#process#unregister(self)
endfunction

function! s:parser_pipe.parse(record) abort
  let chunk = self._chunk
  let revisions = self.revisions
  call extend(chunk, s:parse_record(a:record))
  if !has_key(chunk, 'filename')
    return
  endif
  if !has_key(revisions, chunk.revision)
    let revisions[chunk.revision] = chunk
    let chunk = {
          \ 'filename': chunk.filename,
          \ 'revision': chunk.revision,
          \ 'lnum_ori': chunk.lnum_ori,
          \ 'lnum_fin': chunk.lnum_fin,
          \ 'nlines': chunk.nlines,
          \}
  endif
  call add(self.chunks, chunk)
  let self._chunk = {}
endfunction


" Private --------------------------------------------------------
function! s:parse_record(record) abort
  for [prefix, length, vname] in s:IDENTIFIERS
    if a:record[:length-1] ==# prefix
      return {vname : a:record[length+1:]}
    endif
  endfor
  let terms = split(a:record)
  return {
        \ 'revision': terms[0],
        \ 'lnum_ori': terms[1] + 0,
        \ 'lnum_fin': terms[2] + 0,
        \ 'nlines': get(terms, 3, 1) + 0,
        \}
endfunction

function! s:compare_chunks(lhs, rhs) abort
  return a:lhs.lnum_fin - a:rhs.lnum_fin
endfunction
