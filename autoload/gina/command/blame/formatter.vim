scriptencoding utf-8
let s:String = vital#gina#import('Data.String')
let s:DateTime = vital#gina_blame#import('DateTime')


function! gina#command#blame#formatter#new(width, content, revisions) abort
  let formatter = copy(s:formatter)
  let formatter.width = a:width
  let formatter.content = a:content
  let formatter.revisions = a:revisions
  let formatter.timestamper = s:new_timestamper()
  let formatter._cache_navi = {}
  return formatter
endfunction


" Formatter ------------------------------------------------------------------
let s:formatter = {}

function! s:formatter._format_navi(chunk) abort
  if has_key(self._cache_navi, a:chunk.revision)
    return self._cache_navi[a:chunk.revision]
  endif
  let revinfo = self.revisions[a:chunk.revision]
  let revinfo.timestamp = has_key(revinfo, 'timestamp')
        \ ? revinfo.timestamp
        \ : self.timestamper.format(revinfo.author_time, revinfo.author_tz)
  let suffix = ' ' . revinfo.timestamp . ' ' . revinfo.revision[:7]
  let length = self.width - len(suffix)
  let author = len(revinfo.author) > length
        \ ? s:String.truncate_skipping(revinfo.author, length, 2, '⋯')
        \ : revinfo.author
  let navi = [
        \ s:String.truncate_skipping(revinfo.summary, self.width, 2, '⋯'),
        \ s:String.pad_right(author, length) . suffix,
        \]
  let self._cache_navi[a:chunk.revision] = navi
  return navi
endfunction

function! s:formatter.format(chunk) abort
  let spacer = repeat([''], max([2, a:chunk.nlines]))
  let navi = self._format_navi(a:chunk)
  let body = self.content[a:chunk.lnum_fin - 1 : a:chunk.lnum_fin - 2 + a:chunk.nlines]
  return {
        \ 'navi': navi + spacer[len(navi):] + ['', ''],
        \ 'body': body + spacer[len(body):] + ['', ''],
        \}
endfunction


" Timestamper ----------------------------------------------------------------
let s:timestamper = {}

function! s:timestamper._timezone(timezone) abort
  if has_key(self._cache_timezone, a:timezone)
    return self._cache_timezone[a:timezone]
  endif
  let timezone = s:DateTime.timezone(a:timezone)
  le self._cache_timezone[a:timezone] = timezone
  return timezone
endfunction

function! s:timestamper._datetime(epoch, timezone) abort
  let cname = a:epoch . a:timezone
  if has_key(self._cache_datetime, cname)
    return self._cache_datetime[cname]
  endif
  let timezone = self._timezone(a:timezone)
  let datetime = s:DateTime.from_unix_time(a:epoch, timezone)
  le self._cache_datetime[cname] = datetime
  return datetime
endfunction

function! s:timestamper.format(epoch, timezone) abort
  let cname = a:epoch . a:timezone
  if has_key(self._cache_timestamp, cname)
    return self._cache_timestamp[cname]
  endif
  let datetime = self._datetime(a:epoch, a:timezone)
  let timedelta = datetime.delta(self._now)
  if timedelta.duration().months() < 3
    let timestamp = timedelta.about()
  elseif datetime.year() == self._now.year()
    let timestamp = 'on ' . datetime.strftime('%d %b')
  else
    let timestamp = 'on ' . datetime.strftime('%d %b, %Y')
  endif
  let self._cache_timestamp[cname] = timestamp
  return timestamp
endfunction

function! s:new_timestamper() abort
  let timestamper = copy(s:timestamper)
  let timestamper._now = s:DateTime.now()
  let timestamper._cache_timezone = {}
  let timestamper._cache_datetime = {}
  let timestamper._cache_timestamp = {}
  return timestamper
endfunction

