DESTDIR=~/.vim

install:
	mkdir -p ${DESTDIR}/perl/VIM/
	mkdir -p ${DESTDIR}/plugin
	install plugin/cmake-project.vim ${DESTDIR}/plugin/
	install perl/VIM/CMakeProject.pm ${DESTDIR}/perl/VIM/
	mkdir -p ${DESTDIR}/doc/
	install doc/cmake-project.txt ${DESTDIR}/doc/

uninstall:
	rm ${DESTDIR}/plugin/cmake-project.vim
	rm ${DESTDIR}/perl/VIM/CMakeProject.pm
	rm ${DESTDIR}/doc/cmake-project.txt
