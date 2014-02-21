DESTDIR=~/.vim

install:
	mkdir -p ${DESTDIR}/plugin
	mkdir -p ${DESTDIR}/doc
	cp -r plugin/cmake-project.vim ${DESTDIR}/plugin/
	cp -r doc/* ${DESTDIR}/doc

uninstall:
	rm ${DESTDIR}/plugin/cmake-project.vim
	rm ${DESTDIR}/doc/cmake-project.txt
