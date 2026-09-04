function(mac2win_add_deploy_targets target)
    set(options)
    set(oneValueArgs QT_MAJOR DESTINATION PACKAGE_OUTPUT PACKAGE_NAME VERSION PUBLISHER PACKAGE_ICON)
    set(multiValueArgs EXTRA_DLL_DIRS)
    cmake_parse_arguments(M2W "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    foreach(required QT_MAJOR DESTINATION PACKAGE_OUTPUT PACKAGE_NAME VERSION)
        if(NOT M2W_${required})
            message(FATAL_ERROR "mac2win_add_deploy_targets: ${required} is required")
        endif()
    endforeach()

    get_filename_component(_sdk_root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)
    set(_dll_search_args)
    foreach(_dll_dir IN LISTS M2W_EXTRA_DLL_DIRS)
        list(APPEND _dll_search_args --search "${_dll_dir}")
    endforeach()
    set(_package_icon_args)
    if(M2W_PACKAGE_ICON)
        list(APPEND _package_icon_args --icon "${M2W_PACKAGE_ICON}")
    endif()
    add_custom_target(${target}_deploy
        COMMAND "${_sdk_root}/bin/mingwdeployqt"
            --qt "${M2W_QT_MAJOR}"
            --source "$<TARGET_FILE:${target}>"
            --dest "${M2W_DESTINATION}"
            ${_dll_search_args}
        DEPENDS ${target}
        VERBATIM)

    add_custom_target(${target}_package
        COMMAND "${_sdk_root}/bin/makensis-package"
            --source "${M2W_DESTINATION}"
            --output "${M2W_PACKAGE_OUTPUT}"
            --name "${M2W_PACKAGE_NAME}"
            --version "${M2W_VERSION}"
            --exe "$<TARGET_FILE_NAME:${target}>"
            --publisher "${M2W_PUBLISHER}"
            ${_package_icon_args}
        DEPENDS ${target}_deploy
        VERBATIM)
endfunction()
