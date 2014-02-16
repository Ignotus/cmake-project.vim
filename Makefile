DESTDIR=~/.vim

install:
	cp -r plugin/cmake-project.vim ~/.vim/plugin/

uninstall:
	rm ${DESTDIR}/plugin/cmake-project.vim
