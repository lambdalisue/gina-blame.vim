if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gina-blame-navi'

sign define GinaPseudoSeparatorSign texthl=SignColumn linehl=GinaPseudoSeparator
sign define GinaPseudoEmptySign

highlight default link GinaPseudoSeparator GinaPseudoSeparatorDefault
highlight default link GinaHorizontal Comment
highlight default link GinaSummary    Title
highlight default link GinaMetaInfo   Comment
highlight default link GinaAuthor     Identifier
highlight default link GinaNotCommittedYet Constant
highlight default link GinaTimeDelta  Comment
highlight default link GinaRevision   String
highlight default link GinaLineNr     LineNr

syntax clear
syntax match GinaSummary   /.*/ contains=GinaLineNr,GinaMetaInfo
syntax match GinaLineNr    /^\s*[0-9]\+/
syntax match GinaMetaInfo  /\%(\w\+ authored\|Not committed yet\) .*$/
      \ contains=GinaAuthor,GinaNotCommittedYet,GinaTimeDelta,GinaRevision
syntax match GinaAuthor    /\w\+\ze authored/ contained
syntax match GinaNotCommittedYet /Not committed yet/ contained
syntax match GinaTimeDelta /authored \zs.*\ze\s\+[0-9a-fA-F]\{7}$/ contained
syntax match GinaRevision  /[0-9a-fA-F]\{7}$/ contained
